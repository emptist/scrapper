import Foundation
import SwiftSoup

/// Service for parsing HTML content and extracting video and article information
public class HTMLParserService: HTMLParsing, VideoDetecting, ContentExtracting {
    private let urlSession: URLSessionProtocol
    private let logger: Logging
    
    public init(urlSession: URLSessionProtocol = URLSession.shared, logger: Logging = DefaultLogger()) {
        self.urlSession = urlSession
        self.logger = logger
    }
    
    // MARK: - HTMLParsing Protocol Implementation
    
    public func parse(html: String, baseUrl: String) async throws -> ParsedHTML {
        logger.info("Parsing HTML content from \(baseUrl)")
        
        let videos = try await extractVideoElements(from: html, baseUrl: baseUrl)
        let articles = try await extractArticles(from: html, baseUrl: baseUrl)
        let scripts = try extractScriptTags(from: html)
        let styles = try extractStyleTags(from: html)
        let links = extractLinks(from: html)
        
        return ParsedHTML(
            document: html,
            baseUrl: baseUrl,
            videos: videos,
            articles: articles,
            scripts: scripts,
            styles: styles,
            links: links
        )
    }
    
    public func extractVideoElements(from html: String, baseUrl: String) async throws -> [DetectedVideo] {
        logger.info("Extracting video elements from HTML")
        
        var detectedVideos: [DetectedVideo] = []
        
        // Extract HTML5 video elements
        let html5Videos = try await detectHTML5Videos(in: html, baseUrl: baseUrl)
        detectedVideos.append(contentsOf: html5Videos)
        
        // Extract iframe embeds
        let iframeVideos = try await detectIframeVideos(in: html, baseUrl: baseUrl)
        detectedVideos.append(contentsOf: iframeVideos)
        
        // Extract embed/object elements
        let embedVideos = try await detectEmbedVideos(in: html, baseUrl: baseUrl)
        detectedVideos.append(contentsOf: embedVideos)
        
        // Detect JavaScript-rendered videos
        let jsVideos = try await detectJavaScriptVideos(in: html, baseUrl: baseUrl)
        detectedVideos.append(contentsOf: jsVideos)
        
        // Remove duplicates based on URL
        detectedVideos = removeDuplicateVideos(detectedVideos)
        
        logger.info("Found \(detectedVideos.count) video elements")
        return detectedVideos
    }
    
    // MARK: - VideoDetecting Protocol Implementation
    
    public func detectVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        return try await extractVideoElements(from: html, baseUrl: baseUrl)
    }
    
    public func resolveUrl(_ url: String, baseUrl: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return url
        }
        
        if url.hasPrefix("//") {
            return "https:" + url
        }
        
        if url.hasPrefix("/") {
            guard let baseURL = URL(string: baseUrl) else { return url }
            return baseURL.scheme! + "://" + baseURL.host! + url
        }
        
        // Relative path
        if let baseURL = URL(string: baseUrl) {
            return baseURL.appendingPathComponent(url).absoluteString
        }
        
        return url
    }
    
    public func extractVideoMetadata(from attributes: [String: String], url: String) -> [String: String] {
        var metadata: [String: String] = [:]
        
        // Extract resolution from attributes
        if let width = attributes["width"], let height = attributes["height"] {
            metadata["resolution"] = "\(width)x\(height)"
        }
        
        // Extract duration from attributes
        if let duration = attributes["duration"] {
            metadata["duration"] = duration
        }
        
        // Extract format from URL
        let format = VideoFormat(from: url)
        metadata["format"] = format.rawValue
        
        // Extract quality information
        if let quality = attributes["quality"] {
            metadata["quality"] = quality
        }
        
        // Extract video source information
        if let src = attributes["src"] {
            metadata["source"] = src
        }
        
        return metadata
    }
    
    // MARK: - ContentExtracting Protocol Implementation
    
    public func extractArticles(from html: String, baseUrl: String) async throws -> [DetectedArticle] {
        logger.info("Extracting articles from HTML")
        // Delegate to the existing implementation
        return try await extractArticlesFromHTML(html, baseUrl: baseUrl)
    }
    
    public func extractPublicationDate(from html: String) -> Date? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Try meta tags with property or name containing "date"
            let dateMetaTags = try doc.select("meta[property*=date], meta[name*=date]")
            for metaTag in dateMetaTags {
                if let content = try? metaTag.attr("content"), !content.isEmpty {
                    if let date = parseDate(content) {
                        return date
                    }
                }
            }
            
            // Try time tags with datetime attribute
            let timeTags = try doc.select("time[datetime]")
            for timeTag in timeTags {
                if let datetime = try? timeTag.attr("datetime"), !datetime.isEmpty {
                    if let date = parseDate(datetime) {
                        return date
                    }
                }
            }
            
            // Fallback to regex for common date patterns
            let datePatterns = [
                #"(\d{4}-\d{2}-\d{2})"#,
                #"(\d{1,2}/\d{1,2}/\d{4})"#
            ]
            
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
                    for match in matches {
                        if match.numberOfRanges > 1,
                           let range = Range(match.range(at: 1), in: html) {
                            let dateString = String(html[range])
                            if let date = parseDate(dateString) {
                                return date
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("Error extracting publication date: \(error)")
        }
        
        return nil
    }
    
    public func extractAuthor(from html: String) -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Try meta tags with property or name containing "author"
            let authorMetaTags = try doc.select("meta[property*=author], meta[name*=author]")
            for metaTag in authorMetaTags {
                if let content = try? metaTag.attr("content"), !content.isEmpty {
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Try span or div tags with class containing "author"
            let authorElements = try doc.select("span[class*=author], div[class*=author]")
            for element in authorElements {
                if let text = try? element.text(), !text.isEmpty {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            logger.error("Error extracting author: \(error)")
        }
        
        return nil
    }
    
    public func extractTitle(from html: String) -> String {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Try title tag first
            if let titleElement = try doc.select("title").first(),
               let titleText = try? titleElement.text(), !titleText.isEmpty {
                return titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Fallback to h1 tag
            if let h1Element = try doc.select("h1").first(),
               let h1Text = try? h1Element.text(), !h1Text.isEmpty {
                return h1Text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            logger.error("Error extracting title: \(error)")
        }
        
        return "Untitled"
    }
    
    // MARK: - Private Helper Methods
    
    private func detectHTML5Videos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        var videos: [DetectedVideo] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            let videoElements = try doc.select("video")
            
            for videoElement in videoElements {
                let attributes = try extractAttributes(from: videoElement)
                
                // Extract video sources from source tags
                let sourceElements = try videoElement.select("source")
                for sourceElement in sourceElements {
                    if let src = try? sourceElement.attr("src"), !src.isEmpty {
                        let videoUrl = resolveUrl(src, baseUrl: baseUrl)
                        
                        let detectedVideo = DetectedVideo(
                            url: videoUrl,
                            title: attributes["title"],
                            embedType: .html5,
                            attributes: attributes,
                            position: ElementPosition(line: 0, column: 0, elementIndex: 0, parentPath: ""),
                            context: attributes["poster"]
                        )
                        
                        videos.append(detectedVideo)
                    }
                }
                
                // Handle direct src attribute on video tag
                if let src = try? videoElement.attr("src"), !src.isEmpty {
                    let videoUrl = resolveUrl(src, baseUrl: baseUrl)
                    
                    let detectedVideo = DetectedVideo(
                        url: videoUrl,
                        title: attributes["title"],
                        embedType: .html5,
                        attributes: attributes,
                        position: ElementPosition(line: 0, column: 0, elementIndex: 0, parentPath: ""),
                        context: attributes["poster"]
                    )
                    
                    videos.append(detectedVideo)
                }
            }
        } catch {
            logger.error("Error detecting HTML5 videos: \(error)")
            throw error
        }
        
        return videos
    }
    
    private func detectIframeVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        var videos: [DetectedVideo] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            let iframeElements = try doc.select("iframe")
            
            for iframeElement in iframeElements {
                if let src = try? iframeElement.attr("src"), !src.isEmpty {
                    let attributes = try extractAttributes(from: iframeElement)
                    
                    // Check if this iframe contains video content
                    if isVideoIframe(src) {
                        let videoUrl = resolveUrl(src, baseUrl: baseUrl)
                        
                        let detectedVideo = DetectedVideo(
                            url: videoUrl,
                            title: attributes["title"],
                            embedType: .iframe,
                            attributes: attributes,
                            position: ElementPosition(line: 0, column: 0, elementIndex: 0, parentPath: ""),
                            context: attributes["width"] != nil ? "embedded iframe" : nil
                        )
                        
                        videos.append(detectedVideo)
                    }
                }
            }
        } catch {
            logger.error("Error detecting iframe videos: \(error)")
            throw error
        }
        
        return videos
    }
    
    private func detectEmbedVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        var videos: [DetectedVideo] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            let embedElements = try doc.select("embed")
            
            for embedElement in embedElements {
                if let src = try? embedElement.attr("src"), !src.isEmpty {
                    let attributes = try extractAttributes(from: embedElement)
                    
                    if isVideoEmbed(src) {
                        let videoUrl = resolveUrl(src, baseUrl: baseUrl)
                        
                        let detectedVideo = DetectedVideo(
                            url: videoUrl,
                            title: attributes["title"],
                            embedType: .embed,
                            attributes: attributes,
                            position: ElementPosition(line: 0, column: 0, elementIndex: 0, parentPath: ""),
                            context: attributes["type"]
                        )
                        
                        videos.append(detectedVideo)
                    }
                }
            }
        } catch {
            logger.error("Error detecting embed videos: \(error)")
            throw error
        }
        
        return videos
    }
    
    private func detectJavaScriptVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        var videos: [DetectedVideo] = []
        
        // For JavaScript videos, we still need to use regex since they're typically in script tags
        // Look for JavaScript patterns that load videos
        let jsPatterns = [
            #"src\s*:\s*["']([^"']*\.mp4[^"']*)["']"#,
            #"src\s*:\s*["']([^"']*\.webm[^"']*)["']"#,
            #"src\s*:\s*["']([^"']*video[^"']*)["']"#,
            #"videoUrl\s*=\s*["']([^"']*)["']"#,
            #"video_source\s*=\s*["']([^"']*)["']"#
        ]
        
        do {
            let doc = try SwiftSoup.parse(html)
            let scriptElements = try doc.select("script")
            
            for scriptElement in scriptElements {
                if let scriptContent = try? scriptElement.html() {
                    for pattern in jsPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                            let matches = regex.matches(in: scriptContent, options: [], range: NSRange(location: 0, length: scriptContent.utf8.count))
                            
                            for match in matches {
                                if match.numberOfRanges > 1,
                                   let range = Range(match.range(at: 1), in: scriptContent) {
                                    let videoUrl = resolveUrl(String(scriptContent[range]), baseUrl: baseUrl)
                                    
                                    let detectedVideo = DetectedVideo(
                                        url: videoUrl,
                                        title: nil,
                                        embedType: .javascript,
                                        attributes: [:],
                                        position: ElementPosition(line: 0, column: 0, elementIndex: 0, parentPath: ""),
                                        context: "JavaScript-rendered"
                                    )
                                    
                                    videos.append(detectedVideo)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("Error detecting JavaScript videos: \(error)")
        }
        
        return videos
    }
    
    private func extractAttributes(from element: Element) throws -> [String: String] {
        var attributes: [String: String] = [:]
        
        // Use SwiftSoup's public API to get all attribute keys and values
        // Get the outerHTML and extract attributes using a simple approach
        let outerHtml = try element.outerHtml()
        
        // Use a regular expression to extract all attributes
        do {
            let attributeRegex = try NSRegularExpression(pattern: "([a-zA-Z-]+)\\s*=\\s*([\"'])([^\"']*)\\2", options: [])
            let matches = attributeRegex.matches(in: outerHtml, options: [], range: NSRange(outerHtml.startIndex..., in: outerHtml))
            
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: outerHtml),
                   let valueRange = Range(match.range(at: 2), in: outerHtml) {
                    let key = String(outerHtml[keyRange])
                    let value = String(outerHtml[valueRange])
                    attributes[key] = value
                }
            }
        } catch {
            logger.debug("Regex attribute extraction failed: \(error)")
        }
        
        // Fallback: manually check common attributes using SwiftSoup's public attr method
        let commonAttributes = ["href", "src", "class", "id", "title", "alt", "width", "height", "style"]
        for attr in commonAttributes {
            let value = try element.attr(attr)
            if !value.isEmpty {
                attributes[attr] = value
            }
        }
        
        return attributes
    }
    
    private func extractArticleInfo(from articleElement: Element, baseUrl: String) async throws -> DetectedArticle? {
        // Extract title, author, date, content, and videos
        let title = try articleElement.select("h1, h2, h3, h4, h5, h6").first()?.text() ?? ""
        let author = try articleElement.select("[class*=author], [rel*=author]")
            .first()?.text() ?? extractAuthor(from: try articleElement.outerHtml())

        // Extract date from element
        var date: Date?
        if let timeElement = try articleElement.select("time").first(),
           let datetime = try? timeElement.attr("datetime") {
            date = parseDate(datetime)
        } else {
            date = extractPublicationDate(from: try articleElement.outerHtml())
        }

        // Extract videos within the article
        var videoPositions: [VideoPosition] = []
        let videos = try await detectVideos(in: articleElement.outerHtml(), baseUrl: baseUrl)

        for (index, video) in videos.enumerated() {
            // Generate a UUID from the video URL string for the VideoPosition
            let videoUUID = UUID(uuidString: video.url) ?? UUID()
            videoPositions.append(VideoPosition(
                videoId: videoUUID,
                positionInArticle: index,
                context: video.context
            ))
        }

        // Create article URL (using baseUrl if no specific URL)
        let articleUrl = baseUrl

        return DetectedArticle(
            url: articleUrl,
            title: title,
            publicationDate: date,
            author: author,
            content: try articleElement.text(),
            videoReferences: [],
            metadata: [:]
        )
    }
    
    private func extractArticleInfo(from doc: Document, baseUrl: String) async throws -> DetectedArticle? {
        // For whole document, extract main content
        let title = extractTitle(from: try doc.outerHtml())
        let author = extractAuthor(from: try doc.outerHtml())
        let date = extractPublicationDate(from: try doc.outerHtml())
        
        // Extract videos from the whole document
        var videoPositions: [VideoPosition] = []
        let videos = try await detectVideos(in: doc.outerHtml(), baseUrl: baseUrl)
        
        for (index, video) in videos.enumerated() {
            // Generate a UUID from the video URL string for the VideoPosition
            let videoUUID = UUID(uuidString: video.url) ?? UUID()
            videoPositions.append(VideoPosition(
                videoId: videoUUID,
                positionInArticle: index,
                context: nil,
                elementInfo: [:]
            ))
        }
        
        return DetectedArticle(
            url: baseUrl,
            title: title,
            publicationDate: date,
            author: author,
            content: try doc.text(),
            videoReferences: [],
            metadata: [:]
        )
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try multiple date formats
        // Create standard date formatters
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // ISO with timezone
        
        let dateFormatter2 = DateFormatter()
        dateFormatter2.dateFormat = "MM/dd/yyyy"
        
        let dateFormatter3 = DateFormatter()
        dateFormatter3.dateFormat = "yyyy-MM-dd"
        
        // Ensure all formatters are DateFormatter type
        let dateFormatters: [DateFormatter] = [
            dateFormatter1,
            dateFormatter2,
            dateFormatter3
        ]
        
        // Try ISO8601 formatter separately
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func isVideoIframe(_ src: String) -> Bool {
        let videoDomains = ["youtube", "vimeo", "dailymotion", "twitch", "wistia", "jwplayer"]
        return videoDomains.contains { src.lowercased().contains($0) }
    }
    
    private func isVideoEmbed(_ src: String) -> Bool {
        return src.lowercased().contains("video") || 
               src.lowercased().contains("youtube") ||
               src.lowercased().contains("vimeo")
    }
    
    private func removeDuplicateVideos(_ videos: [DetectedVideo]) -> [DetectedVideo] {
        var seenUrls = Set<String>()
        return videos.filter { video in
            if seenUrls.contains(video.url) {
                return false
            }
            seenUrls.insert(video.url)
            return true
        }
    }
    
    private func removeDuplicateArticles(_ articles: [DetectedArticle]) -> [DetectedArticle] {
        var seenUrls = Set<String>()
        return articles.filter { article in
            if seenUrls.contains(article.url) {
                return false
            }
            seenUrls.insert(article.url)
            return true
        }
    }
    
    private func extractScriptTags(from html: String) throws -> [String] {
        let doc = try SwiftSoup.parse(html)
        let scriptElements = try doc.select("script[src]")
        
        return try scriptElements.map { try $0.attr("src") }.filter { !$0.isEmpty }
    }
    
    private func extractStyleTags(from html: String) throws -> [String] {
        let doc = try SwiftSoup.parse(html)
        let styleElements = try doc.select("link[rel=stylesheet], link[rel='stylesheet']")
        
        return try styleElements.map { try $0.attr("href") }.filter { !$0.isEmpty }
    }
    
    // Link extraction is handled by the regex implementation below
    
    private func extractArticlesFromHTML(_ html: String, baseUrl: String) async throws -> [DetectedArticle] {
        logger.info("Extracting articles from HTML")
        
        var detectedArticles: [DetectedArticle] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Extract articles using article tags
            let articleElements = try doc.select("article")
            for articleElement in articleElements {
                if let article = try await extractArticleInfo(from: articleElement, baseUrl: baseUrl) {
                    detectedArticles.append(article)
                }
            }
            
            // Extract articles using div with class containing "article", "post", or "entry"
            let articleDivs = try doc.select("div[class*=article], div[class*=post], div[class*=entry]")
            for divElement in articleDivs {
                if let article = try await extractArticleInfo(from: divElement, baseUrl: baseUrl) {
                    // Avoid duplicates
                    if !detectedArticles.contains(where: { $0.url == article.url }) {
                        detectedArticles.append(article)
                    }
                }
            }
            
            // If no articles found, treat the whole page as one article
            if detectedArticles.isEmpty {
                if let wholePageArticle = try await extractArticleInfo(from: doc, baseUrl: baseUrl) {
                    detectedArticles.append(wholePageArticle)
                }
            }
        } catch {
            logger.error("Error extracting articles: \(error)")
            throw error
        }
        
        // Remove duplicates
        detectedArticles = removeDuplicateArticles(detectedArticles)
        
        logger.info("Found \(detectedArticles.count) articles")
        return detectedArticles
    }
    
    private func extractLinks(from html: String) -> [String] {
        do {
            // Try using SwiftSoup first for better parsing
            let doc = try SwiftSoup.parse(html)
            let linkElements = try doc.select("a[href]")
            
            return try linkElements.map { try $0.attr("href") }.filter { !$0.isEmpty }
        } catch {
            // Fall back to regex if SwiftSoup parsing fails
            let linkPattern = #"<a[^>]*href="([^"]*)"[^>]*>"#
            let regex = try? NSRegularExpression(pattern: linkPattern)
            
            guard let regex = regex else { return [] }
            
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            return matches.compactMap { match in
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else {
                    return nil
                }
                return String(html[range])
            }
        }
    }
    
    private func extractArticleInfo(from articleHtml: String, baseUrl: String) throws -> DetectedArticle? {
        let title = extractTitle(from: articleHtml)
        let publicationDate = extractPublicationDate(from: articleHtml)
        let author = extractAuthor(from: articleHtml)
        
        // Extract video references from the article content
        let videoReferences = extractVideoReferences(from: articleHtml)
        
        let metadata = extractArticleMetadata(from: articleHtml)
        
        return DetectedArticle(
            url: baseUrl,
            title: title,
            publicationDate: publicationDate,
            author: author,
            content: articleHtml,
            videoReferences: videoReferences,
            metadata: metadata
        )
    }
    
    private func extractVideoReferences(from html: String) -> [VideoReference] {
        var references: [VideoReference] = []
        
        // Find video elements and their positions
        let videoPatterns = [
            #"<video[^>]*>.*?</video>"#,
            #"<iframe[^>]*src="[^"]*"[^>]*>.*?</iframe>"#
        ]
        
        for pattern in videoPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            guard let regex = regex else { continue }
            
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            for (index, match) in matches.enumerated() {
                guard let range = Range(match.range, in: html) else { continue }
                
                let videoElement = String(html[range])
                let videoId = "video_\(index)"
                
                let context = extractVideoContext(from: videoElement)
                let elementInfo = extractAttributes(from: videoElement)
                
                let reference = VideoReference(
                    videoId: videoId,
                    position: index,
                    context: context,
                    elementInfo: elementInfo
                )
                
                references.append(reference)
            }
        }
        
        return references
    }
    
    private func extractVideoContext(from videoElement: String) -> String? {
        // Look for surrounding text or descriptions
        let contextPattern = #"<p[^>]*>(.*?)</p>"#
        let regex = try? NSRegularExpression(pattern: contextPattern)
        
        guard let regex = regex,
              let match = regex.firstMatch(in: videoElement, options: [], range: NSRange(location: 0, length: videoElement.utf8.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: videoElement) else {
            return nil
        }
        
        let context = String(videoElement[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return context.isEmpty ? nil : context
    }
    
    private func extractAttributes(from element: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        // Extract common video attributes
        let attributePattern = #"([^=\s]+)="([^"]*)"#
        let regex = try? NSRegularExpression(pattern: attributePattern)
        
        guard let regex = regex else { return attributes }
        
        let matches = regex.matches(in: element, options: [], range: NSRange(location: 0, length: element.utf8.count))
        
        for match in matches {
            guard match.numberOfRanges > 2,
                  let nameRange = Range(match.range(at: 1), in: element),
                  let valueRange = Range(match.range(at: 2), in: element) else {
                continue
            }
            
            let name = String(element[nameRange])
            let value = String(element[valueRange])
            attributes[name] = value
        }
        
        return attributes
    }
    
    private func extractArticleMetadata(from html: String) -> [String: String] {
        var metadata: [String: String] = [:]
        
        let metaPattern = #"<meta[^>]*name="([^"]*)"[^>]*content="([^"]*)"[^>]*>"#
        let regex = try? NSRegularExpression(pattern: metaPattern)
        
        guard let regex = regex else { return metadata }
        
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
        
        for match in matches {
            guard match.numberOfRanges > 2,
                  let nameRange = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            
            let name = String(html[nameRange])
            let content = String(html[contentRange])
            metadata[name] = content
        }
        
        return metadata
    }
    
    // Article extraction implementation is already defined earlier in the file
}

// MARK: - Helper for Array chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map { startIndex in
            let endIndex = Swift.min(startIndex + size, count)
            return Array(self[startIndex..<endIndex])
        }
    }
}