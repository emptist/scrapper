import Foundation

/// Represents a video found on a web page
public struct Video: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: String
    public let title: String?
    public let format: VideoFormat
    public let resolution: String?
    public let duration: TimeInterval?
    public let hostingSource: String
    public let embedType: EmbedType
    public let metadata: [String: String]
    public let thumbnailUrl: String?
    public let discoveredAt: Date
    
    public init(
        id: UUID = UUID(),
        url: String,
        title: String? = nil,
        format: VideoFormat,
        resolution: String? = nil,
        duration: TimeInterval? = nil,
        hostingSource: String,
        embedType: EmbedType,
        metadata: [String: String] = [:],
        thumbnailUrl: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.format = format
        self.resolution = resolution
        self.duration = duration
        self.hostingSource = hostingSource
        self.embedType = embedType
        self.metadata = metadata
        self.thumbnailUrl = thumbnailUrl
        self.discoveredAt = Date()
    }
}

/// Represents the format of a video
public enum VideoFormat: String, Codable, CaseIterable, Sendable {
    case mp4 = "mp4"
    case webm = "webm"
    case ogg = "ogg"
    case avi = "avi"
    case mov = "mov"
    case flv = "flv"
    case mkv = "mkv"
    case unknown = "unknown"
    
    public init(from url: String) {
        let pathExtension = URL(string: url)?.pathExtension.lowercased() ?? ""
        self = VideoFormat(rawValue: pathExtension) ?? .unknown
    }
}

/// Represents how a video is embedded on a page
public enum EmbedType: String, Codable, CaseIterable, Sendable {
    case html5 = "html5"
    case iframe = "iframe"
    case javascript = "javascript"
    case flash = "flash"
    case embed = "embed"
    case object = "object"
    case unknown = "unknown"
    
    public init(from tagName: String, attributes: [String: String]) {
        let tag = tagName.lowercased()
        
        switch tag {
        case "video":
            self = .html5
        case "iframe":
            self = .iframe
        case "embed":
            self = .embed
        case "object":
            self = .object
        default:
            // Check for JavaScript-rendered content
            if attributes["data-video"] != nil || attributes["class"]?.contains("video") == true {
                self = .javascript
            } else {
                self = .unknown
            }
        }
    }
}