import Foundation

/// Protocol for the main video analysis engine
public protocol VideoAnalyzerEngine {
    /// Analyze a web page and extract video information
    func analyze(url: String) async throws -> SiteAnalysis

    /// Analyze multiple URLs concurrently
    func analyze(urls: [String]) async throws -> [SiteAnalysis]

    /// Get detailed video information for a specific video URL
    func getVideoDetails(for url: String) async throws -> VideoUrlDetail

    /// Export analysis results in specified format
    func export(_ analysis: SiteAnalysis, format: ExportFormat) async throws -> Data

    /// Validate URLs before analysis
    func validate(url: String) async throws -> ValidationResult
}

/// Main video analyzer engine implementation
public class VideoAnalyzer: VideoAnalyzerEngine {
    private let httpClient: HTTPClient
    private let htmlParser: HTMLParsing
    private let logger: Logging
    private let duplicateDetector: DuplicateDetecting

    public init(
        httpClient: HTTPClient = DefaultHTTPClient(),
        htmlParser: HTMLParsing = HTMLParserService(),
        logger: Logging = DefaultLogger(),
        duplicateDetector: DuplicateDetecting = DefaultDuplicateDetector()
    ) {
        self.httpClient = httpClient
        self.htmlParser = htmlParser
        self.logger = logger
        self.duplicateDetector = duplicateDetector
    }

    public func analyze(url: String) async throws -> SiteAnalysis {
        let startTime = Date()
        logger.info("Starting analysis of URL: \(url)")

        do {
            // Validate the URL
            let validation = try await validate(url: url)
            guard validation.isValid else {
                throw AnalysisError.invalidUrl(validation.errorMessage ?? "URL validation failed")
            }

            // Fetch HTML content
            let htmlContent = try await httpClient.fetchHTML(from: url)

            // Parse HTML and extract content
            let parsedHTML = try await htmlParser.parse(html: htmlContent, baseUrl: url)

            // Convert detected videos to Video objects
            let videos = try await convertToVideos(parsedHTML.videos, baseUrl: url)

            // Convert detected articles to Article objects
            let articles = try await convertToArticles(parsedHTML.articles, videos: videos)

            // Generate video URL details
            let videoUrlDetails = try await generateVideoUrlDetails(videos, articles: articles)

            // Remove duplicates
            let uniqueVideos = duplicateDetector.removeDuplicateVideos(videos)
            let uniqueArticles = duplicateDetector.removeDuplicateArticles(articles)
            let uniqueVideoUrlDetails = duplicateDetector.removeDuplicateVideoUrls(videoUrlDetails)

            let processingTime = Date().timeIntervalSince(startTime)

            let analysis = SiteAnalysis(
                targetUrl: url,
                siteUrl: extractSiteUrl(from: url),
                videos: uniqueVideos,
                articles: uniqueArticles,
                videoUrls: uniqueVideoUrlDetails,
                processingTime: processingTime
            )

            logger.info("Analysis completed successfully. Found \(uniqueVideos.count) videos, \(uniqueArticles.count) articles in \(String(format: "%.2f", processingTime)) seconds")

            return analysis

        } catch {
            logger.error("Analysis failed: \(error.localizedDescription)")
            let processingTime = Date().timeIntervalSince(startTime)
            return SiteAnalysis(
                targetUrl: url,
                siteUrl: extractSiteUrl(from: url),
                videos: [],
                articles: [],
                videoUrls: [],
                processingTime: processingTime,
                errorLog: [error.localizedDescription]
            )
        }
    }

    public func analyze(urls: [String]) async throws -> [SiteAnalysis] {
        logger.info("Starting batch analysis of \(urls.count) URLs")

        // Process URLs concurrently with a concurrency limit
        let maxConcurrent = 5
        var results: [SiteAnalysis] = []

        for batch in urls.chunked(into: maxConcurrent) {
            // Use a different approach to avoid data races in task group
            let batchResults = try await withThrowingTaskGroup(of: SiteAnalysis.self) { group in
                // Process each URL without capturing the method reference
                for url in batch {
                    group.addTask {
                        // Create a fresh instance inside each task
                        let localAnalyzer = VideoAnalyzer(
                            httpClient: DefaultHTTPClient(),
                            htmlParser: HTMLParserService(),
                            logger: DefaultLogger(),
                            duplicateDetector: DefaultDuplicateDetector()
                        )
                        return try await localAnalyzer.analyze(url: url)
                    }
                }

                var batchAnalyses: [SiteAnalysis] = []
                for try await result in group {
                    batchAnalyses.append(result)
                }
                return batchAnalyses
            }
            results.append(contentsOf: batchResults)
        }

        logger.info("Batch analysis completed. Processed \(results.count) URLs")
        return results
    }

    public func getVideoDetails(for url: String) async throws -> VideoUrlDetail {
        logger.info("Getting detailed information for video: \(url)")

        // Create a temporary video object for the URL
        let video = Video(
            url: url,
            format: VideoFormat(from: url),
            hostingSource: extractDomain(from: url),
            embedType: determineEmbedType(from: url)
        )

        let accessibility = try await analyzeVideoAccessibility(video)
        let fileSize = try await getVideoFileSize(video)

        return VideoUrlDetail(
            video: video,
            originalUrl: url,
            resolvedUrl: url,
            fileSize: fileSize,
            accessibility: accessibility
        )
    }

    public func export(_ analysis: SiteAnalysis, format: ExportFormat) async throws -> Data {
        logger.info("Exporting analysis results in \(format.rawValue) format")

        switch format {
        case .json:
            return try JSONEncoder().encode(analysis)
        case .html:
            return await generateHTMLExport(analysis)
        }
    }

    public func validate(url: String) async throws -> ValidationResult {
        logger.info("Validating URL: \(url)")

        guard URL(string: url) != nil else {
            return ValidationResult(isValid: false, errorMessage: "Invalid URL format")
        }

        do {
            let isAccessible = try await httpClient.checkAccessibility(of: url)
            if isAccessible {
                return ValidationResult(isValid: true)
            } else {
                return ValidationResult(isValid: false, errorMessage: "URL is not accessible")
            }
        } catch {
            return ValidationResult(isValid: false, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Private Helper Methods

    private func convertToVideos(_ detectedVideos: [DetectedVideo], baseUrl: String) async throws -> [Video] {
        var videos: [Video] = []

        for detected in detectedVideos {
            do {
                let video = try await createVideo(from: detected, baseUrl: baseUrl)
                videos.append(video)
            } catch {
                logger.warning("Failed to convert detected video: \(error.localizedDescription)")
            }
        }

        return videos
    }

    private func convertToArticles(_ detectedArticles: [DetectedArticle], videos: [Video]) async throws -> [Article] {
        var articles: [Article] = []

        for detected in detectedArticles {
            let videoPositions = convertVideoReferences(detected.videoReferences, videos: videos)

            // Create URL from string, default to empty URL if invalid
            let articleURL = URL(string: detected.url) ?? URL(string: "")!
            // Use correct parameters that exist in the Article model
            let article = Article(
                url: articleURL,
                title: detected.title,
                author: detected.author,
                publicationDate: detected.publicationDate,
                mainContent: detected.content,
                videoPositions: videoPositions
            )

            articles.append(article)
        }

        return articles
    }

    private func generateVideoUrlDetails(_ videos: [Video], articles: [Article]) async throws -> [VideoUrlDetail] {
        var details: [VideoUrlDetail] = []

        for video in videos {
            let detail = try await getVideoDetails(for: video.url)

            // Find related articles
            let relatedArticles = articles.filter { article in
                article.videoPositions.contains(where: { (position: VideoPosition) in
                    position.id.uuidString == video.id.uuidString
                })
            }.map { $0.id }

            let enhancedDetail = VideoUrlDetail(
                video: detail.video,
                originalUrl: detail.originalUrl,
                resolvedUrl: detail.resolvedUrl,
                fileSize: detail.fileSize,
                accessibility: detail.accessibility,
                relatedArticles: relatedArticles
            )

            details.append(enhancedDetail)
        }

        return details
    }

    private func createVideo(from detected: DetectedVideo, baseUrl: String) async throws -> Video {
        let metadata = detected.attributes.merging([
            "position": "\(detected.position.line):\(detected.position.column)",
            "context": detected.context ?? ""
        ]) { (_, new) in new }

        return Video(
            url: detected.url,
            title: detected.title,
            format: VideoFormat(from: detected.url),
            resolution: extractResolution(from: detected.attributes),
            duration: extractDuration(from: detected.attributes),
            hostingSource: extractDomain(from: detected.url),
            embedType: detected.embedType,
            metadata: metadata,
            thumbnailUrl: extractThumbnailUrl(from: detected.attributes)
        )
    }

    private func convertVideoReferences(_ references: [VideoReference], videos: [Video]) -> [VideoPosition] {
        return references.compactMap { reference in
            // First try to find by URL containing videoId
            var foundVideo: Video? = videos.first(where: { $0.url.contains(reference.videoId) })

            // If not found, try by metadata
            if foundVideo == nil {
                foundVideo = videos.first(where: { $0.metadata["videoId"] == reference.videoId })
            }

            guard let video = foundVideo else {
                return nil
            }

            // Extract additional context details from the element info if available

            // Parse the parent tag from element info
            var parentTag: String? = nil
            if let tagInfo = reference.elementInfo["tag"], !tagInfo.isEmpty {
                parentTag = tagInfo
            }

            // Check if video is likely above the fold based on position
            let isAboveTheFold = reference.position <= 3 // Assuming first few videos are above fold

            // Create the enhanced VideoPosition
            return VideoPosition(
                id: video.id,
                xPath: reference.elementInfo["xpath"],
                parentTag: parentTag,
                positionIndex: reference.position,
                isAboveTheFold: isAboveTheFold,
                surroundingText: reference.context,
                contextSection: reference.elementInfo["section"] ?? reference.elementInfo["parentClass"],
                caption: reference.elementInfo["caption"] ?? reference.elementInfo["alt"] ?? reference.elementInfo["title"],
                description: reference.context
            )
        }
    }

    private func analyzeVideoAccessibility(_ video: Video) async throws -> AccessibilityInfo {
        // Check if the video URL is accessible
        let isAccessible = try await httpClient.checkAccessibility(of: video.url)

        // Check if authentication is required (simplified check)
        let requiresAuth = video.url.contains("auth") || video.url.contains("login")

        // Analyze hosting source for additional accessibility info
        let blockedRegions = extractBlockedRegions(from: video.hostingSource)

        return AccessibilityInfo(
            isAccessible: isAccessible,
            requiresAuthentication: requiresAuth,
            blockedRegions: blockedRegions,
            supportedFormats: [video.format]
        )
    }

    private func getVideoFileSize(_ video: Video) async throws -> Int64? {
        // This would typically make a HEAD request to get content-length
        // For now, return nil as we can't easily determine file size without downloading
        return nil
    }

    private func generateHTMLExport(_ analysis: SiteAnalysis) async -> Data {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            \(generateHTMLHead())
        </head>
        <body>
            \(generateHeaderSection(analysis))
            \(generateSummarySection(analysis))
            \(generateVideosSection(analysis))
            \(generateArticlesSection(analysis))
            \(generateVideoDetailsSection(analysis))
            \(generateErrorsSection(analysis))
        </body>
        </html>
        """

        return html.data(using: String.Encoding.utf8) ?? Data()
    }

    private func generateHTMLHead() -> String {
        return """
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Video Analysis Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .header { background-color: #f5f5f5; padding: 20px; border-radius: 8px; }
            .summary { margin: 20px 0; }
            .videos, .articles { margin: 20px 0; }
            .video-item, .article-item {
                border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px;
            }
            .video-url { font-family: monospace; background-color: #f9f9f9; padding: 5px; }
            .metadata { font-size: 0.9em; color: #666; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }

            /* New styles for video position details */
            .video-positions { margin-top: 20px; }
            .video-position {
                background-color: #f9f9f9;
                border-left: 3px solid #4CAF50;
                padding: 12px;
                margin: 10px 0; border-radius: 4px;
            }
            .video-position h5 { margin-top: 0; color: #333; }
            .context-text {
                background-color: #fff;
                border: 1px solid #eee;
                padding: 10px;
                border-radius: 4px;
                font-size: 0.95em;
                line-height: 1.5;
                color: #555;
            }
            .element-info {
                margin-top: 10px; font-size: 0.85em;
            }
            .element-info pre {
                background-color: #f5f5f5;
                padding: 8px; border-radius: 4px;
                overflow-x: auto;
            }
        </style>
        """
    }

    private func generateHeaderSection(_ analysis: SiteAnalysis) -> String {
        return """
        <div class="header">
            <h1>Video Analysis Report</h1>
            <p><strong>Target URL:</strong> \(analysis.targetUrl)</p>
            <p><strong>Site URL:</strong> \(analysis.siteUrl)</p>
            <p><strong>Analysis Date:</strong> \(analysis.analysisDate)</p>
            <p><strong>Processing Time:</strong> \(String(format: "%.2f", analysis.processingTime)) seconds</p>
        </div>
        """
    }

    private func generateSummarySection(_ analysis: SiteAnalysis) -> String {
        return """
        <div class="summary">
            <h2>Summary</h2>
            <ul>
                <li>Total Videos: \(analysis.videos.count)</li>
                <li>Total Articles: \(analysis.articles.count)</li>
                <li>Video URL Details: \(analysis.videoUrls.count)</li>
                \(!analysis.errorLog.isEmpty ? "<li>Errors: \(analysis.errorLog.count)</li>" : "")
            </ul>
        </div>
        """
    }

    private func generateVideosSection(_ analysis: SiteAnalysis) -> String {
        let videosHTML = analysis.videos.map { video -> String in
            """
            <div class="video-item">
                <h3>\(video.title ?? "Untitled Video")</h3>
                <p><strong>URL:</strong> <span class="video-url">\(video.url)</span></p>
                <p><strong>Format:</strong> \(video.format.rawValue)</p>
                <p><strong>Resolution:</strong> \(video.resolution ?? "Unknown")</p>
                <p><strong>Embed Type:</strong> \(video.embedType.rawValue)</p>
                <p><strong>Hosting Source:</strong> \(video.hostingSource)</p>
                \(video.duration != nil ? "<p><strong>Duration:</strong> \(Int(video.duration!)) seconds</p>" : "")
                <div class="metadata">
                    <strong>Metadata:</strong>
                    <pre>\(video.metadata)</pre>
                </div>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <div class="videos">
            <h2>Videos Found (\(analysis.videos.count))</h2>
            \(videosHTML)
        </div>
        """
    }

    private func generateArticlesSection(_ analysis: SiteAnalysis) -> String {
        let articlesHTML = analysis.articles.map { article -> String in
            var articleHTML = """
            <div class="article-item">
                <h3>\(article.title ?? "Untitled Article")</h3>
                <p><strong>URL:</strong> \(article.url)</p>
            """

            if let author = article.author {
                articleHTML += "<p><strong>Author:</strong> \(author)</p>"
            }

            if let date = article.publicationDate {
                articleHTML += "<p><strong>Published:</strong> \(date)</p>"
            }

            articleHTML += "<p><strong>Videos in Article:</strong> \(article.videoPositions.count)</p>"

            if !article.videoPositions.isEmpty {
                articleHTML += generateVideoPositionsHTML(for: article.videoPositions)
            }

            articleHTML += """
                <!-- Metadata section removed as Article doesn't have metadata property -->
            </div>
            """

            return articleHTML
        }.joined(separator: "\n")

        return """
        <div class="articles">
            <h2>Articles with Videos (\(analysis.articles.count))</h2>
            \(articlesHTML)
        </div>
        """
    }

    private func generateVideoPositionsHTML(for positions: [VideoPosition]) -> String {
        let positionsHTML = positions.map { videoPos -> String in
            var positionHTML = """
            <div class="video-position">
                <h5>Video at Position \(videoPos.positionIndex + 1)</h5>
                <p><strong>Video ID:</strong> \(videoPos.id)</p>
                <p><strong>Element Type:</strong> \(videoPos.parentTag ?? "Unknown")</p>
                <p><strong>Fold Position:</strong> \(videoPos.isAboveTheFold ? "Above the fold" : "Below the fold")</p>
            """

            if let caption = videoPos.caption {
                positionHTML += "<p><strong>Caption:</strong> \(caption)</p>"
            }

            if let description = videoPos.description {
                positionHTML += "<p><strong>Description:</strong> \(description)</p>"
            }

            if let surroundingText = videoPos.surroundingText {
                positionHTML += """
                <p><strong>Surrounding Context:</strong></p>
                <div class="context-text">\(surroundingText)</div>
                """
            }

            if let contextSection = videoPos.contextSection {
                positionHTML += "<p><strong>Context Section:</strong> \(contextSection)</p>"
            }

            positionHTML += """
                <!-- Element info removed as VideoPosition doesn't have elementInfo property -->
            </div>
            """

            return positionHTML
        }.joined(separator: "\n")

        return """
        <div class="video-positions">
            <h4>Video Context Details</h4>
            \(positionsHTML)
        </div>
        """
    }

    private func generateVideoDetailsSection(_ analysis: SiteAnalysis) -> String {
        guard !analysis.videoUrls.isEmpty else { return "" }

        let rowsHTML = analysis.videoUrls.map { detail -> String in
            """
            <tr>
                <td>\(detail.originalUrl)</td>
                <td>\(detail.video.format.rawValue)</td>
                <td>\(detail.video.resolution ?? "Unknown")</td>
                <td>\(detail.fileSize != nil ? "\\(detail.fileSize!) bytes" : "Unknown")</td>
                <td>\(detail.accessibility.isAccessible ? "Yes" : "No")</td>
                <td>\(detail.relatedArticles.count)</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <div class="video-details">
            <h2>Video URL Details</h2>
            <table>
                <tr>
                    <th>URL</th>
                    <th>Format</th>
                    <th>Resolution</th>
                    <th>File Size</th>
                    <th>Accessible</th>
                    <th>Related Articles</th>
                </tr>
                \(rowsHTML)
            </table>
        </div>
        """
    }

    private func generateErrorsSection(_ analysis: SiteAnalysis) -> String {
        guard !analysis.errorLog.isEmpty else { return "" }

        let errorsHTML = analysis.errorLog.map { error -> String in
            "<li>\(error)</li>"
        }.joined(separator: "\n")

        return """
        <div class="errors">
            <h2>Errors Encountered</h2>
            <ul>
                \(errorsHTML)
            </ul>
        </div>
        """
    }

    // MARK: - Utility Methods

    private func extractSiteUrl(from url: String) -> String {
        if let urlObject = URL(string: url) {
            return urlObject.scheme! + "://" + urlObject.host!
        }
        return url
    }

    private func extractDomain(from url: String) -> String {
        if let urlObject = URL(string: url) {
            return urlObject.host ?? url
        }
        return url
    }

    private func determineEmbedType(from url: String) -> EmbedType {
        if url.contains("youtube.com") || url.contains("youtu.be") {
            return .iframe
        } else if url.contains("vimeo.com") {
            return .iframe
        } else if url.hasSuffix(".mp4") || url.hasSuffix(".webm") {
            return .html5
        } else {
            return .unknown
        }
    }

    private func extractResolution(from attributes: [String: String]) -> String? {
        if let width = attributes["width"], let height = attributes["height"] {
            return "\(width)x\(height)"
        }
        return attributes["resolution"]
    }

    private func extractDuration(from attributes: [String: String]) -> TimeInterval? {
        if let durationString = attributes["duration"] {
            return TimeInterval(durationString)
        }
        return nil
    }

    private func extractThumbnailUrl(from attributes: [String: String]) -> String? {
        return attributes["poster"] ?? attributes["thumbnail"]
    }

    private func extractBlockedRegions(from hostingSource: String) -> [String] {
        // Simplified implementation - would need more sophisticated logic
        // to check geo-blocking information
        return []
    }

    private func extractExcerpt(from content: String) -> String? {
        // Remove HTML tags and get first paragraph
        let cleanContent = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let paragraphs = cleanContent.components(separatedBy: "\n\n")
        return paragraphs.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

public enum AnalysisError: Error, LocalizedError {
    case invalidUrl(String)
    case parsingFailed(String)
    case videoDetectionFailed(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUrl(let message):
            return "Invalid URL: \(message)"
        case .parsingFailed(let message):
            return "HTML parsing failed: \(message)"
        case .videoDetectionFailed(let message):
            return "Video detection failed: \(message)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}

public struct ValidationResult {
    public let isValid: Bool
    public let errorMessage: String?

    public init(isValid: Bool, errorMessage: String? = nil) {
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
}

public enum ExportFormat: String, CaseIterable, Sendable {
    case json = "json"
    case html = "html"
}
