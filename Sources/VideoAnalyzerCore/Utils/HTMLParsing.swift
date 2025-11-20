import Foundation

/// Protocol for HTML parsing capabilities
public protocol HTMLParsing {
    /// Parse HTML content and extract structured data
    func parse(html: String, baseUrl: String) async throws -> ParsedHTML
    
    /// Extract video elements from HTML
    func extractVideoElements(from html: String, baseUrl: String) async throws -> [DetectedVideo]
    
    /// Extract article elements from HTML
    func extractArticles(from html: String, baseUrl: String) async throws -> [DetectedArticle]
}

/// Represents parsed HTML content
public struct ParsedHTML {
    public let document: String
    public let baseUrl: String
    public let videos: [DetectedVideo]
    public let articles: [DetectedArticle]
    public let scripts: [String]
    public let styles: [String]
    public let links: [String]
    
    public init(document: String, baseUrl: String, videos: [DetectedVideo], articles: [DetectedArticle], scripts: [String], styles: [String], links: [String]) {
        self.document = document
        self.baseUrl = baseUrl
        self.videos = videos
        self.articles = articles
        self.scripts = scripts
        self.styles = styles
        self.links = links
    }
}

/// Represents a video detected in HTML
public struct DetectedVideo {
    public let url: String
    public let title: String?
    public let embedType: EmbedType
    public let attributes: [String: String]
    public let position: ElementPosition
    public let context: String?
    
    public init(url: String, title: String?, embedType: EmbedType, attributes: [String: String], position: ElementPosition, context: String?) {
        self.url = url
        self.title = title
        self.embedType = embedType
        self.attributes = attributes
        self.position = position
        self.context = context
    }
}

/// Represents an article detected in HTML
public struct DetectedArticle {
    public let url: String
    public let title: String
    public let publicationDate: Date?
    public let author: String?
    public let content: String
    public let videoReferences: [VideoReference]
    public let metadata: [String: String]
    
    public init(url: String, title: String, publicationDate: Date?, author: String?, content: String, videoReferences: [VideoReference], metadata: [String: String]) {
        self.url = url
        self.title = title
        self.publicationDate = publicationDate
        self.author = author
        self.content = content
        self.videoReferences = videoReferences
        self.metadata = metadata
    }
}

/// Represents a reference to a video within an article
public struct VideoReference {
    public let videoId: String
    public let position: Int
    public let context: String?
    public let elementInfo: [String: String]
    
    public init(videoId: String, position: Int, context: String?, elementInfo: [String: String]) {
        self.videoId = videoId
        self.position = position
        self.context = context
        self.elementInfo = elementInfo
    }
}

/// Represents the position of an element in the HTML document
public struct ElementPosition {
    public let line: Int
    public let column: Int
    public let elementIndex: Int
    public let parentPath: String
    
    public init(line: Int, column: Int, elementIndex: Int, parentPath: String) {
        self.line = line
        self.column = column
        self.elementIndex = elementIndex
        self.parentPath = parentPath
    }
}

/// Protocol for video detection capabilities
public protocol VideoDetecting {
    /// Detect videos in various formats and embedding types
    func detectVideos(in html: String, baseUrl: String) async throws -> [DetectedVideo]
    
    /// Resolve relative URLs to absolute URLs
    func resolveUrl(_ url: String, baseUrl: String) -> String
    
    /// Extract metadata from video elements
    func extractVideoMetadata(from attributes: [String: String], url: String) -> [String: String]
}

/// Protocol for content extraction capabilities
public protocol ContentExtracting {
    /// Extract article information from HTML
    func extractArticles(from html: String, baseUrl: String) async throws -> [DetectedArticle]
    
    /// Extract publication date from HTML
    func extractPublicationDate(from html: String) -> Date?
    
    /// Extract author information from HTML
    func extractAuthor(from html: String) -> String?
    
    /// Extract article title from HTML
    func extractTitle(from html: String) -> String
}