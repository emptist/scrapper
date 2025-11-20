import Foundation

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
        let scripts = extractScriptTags(from: html)
        let styles = extractStyleTags(from: html)
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
    
    public func extractArticles(from html: String, baseUrl: String) async throws -> [DetectedArticle] {
        logger.info("Extracting articles from HTML")
        
        // Use regex patterns to find article elements
        let articlePatterns = [
            #"<article[^>]*>(.*?)</article>"#,
            #"<div[^>]*class="[^"]*article[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*post[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*entry[^"]*"[^>]*>(.*?)</div>"#
        ]
        
        var detectedArticles: [DetectedArticle] = []
        
        for pattern in articlePatterns {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html),
                      let articleElement = try extractArticleInfo(from: String(html[range]), baseUrl: baseUrl) else {
                    continue
                }
                detectedArticles.append(articleElement)
            }
        }
        
        // If no articles found, treat the whole page as one article
        if detectedArticles.isEmpty {
            let wholePageArticle = try extractArticleInfo(from: html, baseUrl: baseUrl)
            if let article = wholePageArticle {
                detectedArticles.append(article)
            }
        }
        
        // Remove duplicates
        detectedArticles = removeDuplicateArticles(detectedArticles)
        
        logger.info("Found \(detectedArticles.count) articles")
        return detectedArticles
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
        if let format = VideoFormat(from: url).rawValue {
            metadata["format"] = format
        }
        
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
        return try await extractArticlesFromHTML(html, baseUrl: baseUrl)
    }
    
    public func extractPublicationDate(from html: String) -> Date? {
        let datePatterns = [
            #"<meta[^>]*property="[^"]*date[^"]*"[^>]*content="([^"]*)""#,
            #"<meta[^>]*name="[^"]*date[^"]*"[^>]*content="([^"]*)""#,
            #"<time[^>]*datetime="([^"]*)""#,
            #"(\d{4}-\d{2}-\d{2})"#,
            #"(\d{1,2}/\d{1,2}/\d{4})"#
        ]
        
        for pattern in datePatterns {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else {
                    continue
                }
                let dateString = String(html[range])
                
                // Try multiple date formats
                let dateFormatters = [
                    ISO8601DateFormatter(),
                    DateFormatter.dateTime,
                    DateFormatter.monthDayYear,
                    DateFormatter.yearMonthDay
                ]
                
                for formatter in dateFormatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    public func extractAuthor(from html: String) -> String? {
        let authorPatterns = [
            #"<meta[^>]*property="[^"]*author[^"]*"[^>]*content="([^"]*)""#,
            #"<meta[^>]*name="[^"]*author[^"]*"[^>]*content="([^"]*)""#,
            #"<span[^>]*class="[^"]*author[^"]*"[^>]*>(.*?)</span>"#,
            #"<div[^>]*class="[^"]*author[^"]*"[^>]*>(.*?)</div>"#
        ]
        
        for pattern in authorPatterns {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else {
                    continue
                }
                let authorString = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !authorString.isEmpty {
                    return authorString
                }
            }
        }
        
        return nil
    }
    
    public func extractTitle(from html: String) -> String {
        let titlePattern = #"<title[^>]*>(.*?)</title>"#
        let regex = try NSRegularExpression(pattern: titlePattern, options: .caseInsensitive)
        
        if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback to h1 tag
        let h1Pattern = #"<h1[^>]*>(.*?)</h1>"#
        let h1Regex = try NSRegularExpression(pattern: h1Pattern, options: .caseInsensitive)
        
        if let match = h1Regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "Untitled"
    }
    
    // MARK: - Private Helper Methods
    
    private func detectHTML5Videos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        let videoPattern = #"<video[^>]*>(.*?)</video>"#
        let regex = try NSRegularExpression(pattern: videoPattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
        
        var videos: [DetectedVideo] = []
        
        for match in matches {
            guard match.numberOfRanges > 0,
                  let range = Range(match.range(at: 0), in: html) else {
                continue
            }
            
            let videoElement = String(html[range])
            let attributes = extractAttributes(from: videoElement)
            
            // Extract video sources
            let sourcePattern = #"<source[^>]*src="([^"]*)"[^>]*>"#
            let sourceRegex = try NSRegularExpression(pattern: sourcePattern)
            let sourceMatches = sourceRegex.matches(in: videoElement, options: [], range: NSRange(location: 0, length: videoElement.utf8.count))
            
            for sourceMatch in sourceMatches {
                guard sourceMatch.numberOfRanges > 1,
                      let sourceRange = Range(sourceMatch.range(at: 1), in: videoElement) else {
                    continue
                }
                
                let videoUrl = resolveUrl(String(videoElement[sourceRange]), baseUrl: baseUrl)
                let metadata = extractVideoMetadata(from: attributes, url: videoUrl)
                
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
            
            // Handle direct src attribute
            if let src = attributes["src"] {
                let videoUrl = resolveUrl(src, baseUrl: baseUrl)
                let metadata = extractVideoMetadata(from: attributes, url: videoUrl)
                
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
        
        return videos
    }
    
    private func detectIframeVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        let iframePattern = #"<iframe[^>]*src="([^"]*)"[^>]*>(.*?)</iframe>"#
        let regex = try NSRegularExpression(pattern: iframePattern)
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
        
        var videos: [DetectedVideo] = []
        
        for match in matches {
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }
            
            let iframeSrc = String(html[range])
            let attributes = extractAttributes(from: String(html[match.range(at: 0)]))
            
            // Check if this iframe contains video content
            if isVideoIframe(iframeSrc) {
                let videoUrl = resolveUrl(iframeSrc, baseUrl: baseUrl)
                
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
        
        return videos
    }
    
    private func detectEmbedVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        let embedPattern = #"<embed[^>]*src="([^"]*)"[^>]*>"#
        let regex = try NSRegularExpression(pattern: embedPattern)
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
        
        var videos: [DetectedVideo] = []
        
        for match in matches {
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }
            
            let embedSrc = String(html[range])
            let attributes = extractAttributes(from: String(html[match.range(at: 0)]))
            
            if isVideoEmbed(embedSrc) {
                let videoUrl = resolveUrl(embedSrc, baseUrl: baseUrl)
                
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
        
        return videos
    }
    
    private func detectJavaScriptVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo] {
        var videos: [DetectedVideo] = []
        
        // Look for JavaScript patterns that load videos
        let jsPatterns = [
            #"src\s*:\s*["']([^"']*\.mp4[^"']*)["']"#,
            #"src\s*:\s*["']([^"']*\.webm[^"']*)["']"#,
            #"src\s*:\s*["']([^"']*video[^"']*)["']"#,
            #"videoUrl\s*=\s*["']([^"']*)["']"#,
            #"video_source\s*=\s*["']([^"']*)["']"#
        ]
        
        for pattern in jsPatterns {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf8.count))
            
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else {
                    continue
                }
                
                let videoUrl = resolveUrl(String(html[range]), baseUrl: baseUrl)
                
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
        
        return videos
    }
    
    private func extractAttributes(from element: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        let attributePattern = #"(\w+)="([^"]*)""#
        let regex = try? NSRegularExpression(pattern: attributePattern)
        
        if let regex = regex {
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
        }
        
        return attributes
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
    
    private func extractScriptTags(from html: String) -> [String] {
        let scriptPattern = #"<script[^>]*src="([^"]*)"[^>]*>"#
        let regex = try? NSRegularExpression(pattern: scriptPattern)
        
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
    
    private func extractStyleTags(from html: String) -> [String] {
        let stylePattern = #"<link[^>]*rel="stylesheet"[^>]*href="([^"]*)"[^>]*>"#
        let regex = try? NSRegularExpression(pattern: stylePattern)
        
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
    
    private func extractLinks(from html: String) -> [String] {
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
    
    private func extractArticleMetadata(from html: String) -> [String: String] {
        var metadata: [String: String] = []
        
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
    
    private func extractArticlesFromHTML(_ html: String, _ baseUrl: String) async throws -> [DetectedArticle] {
        return try await extractArticles(from: html, baseUrl: baseUrl)
    }
}