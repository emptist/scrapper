import Foundation

/// Represents an article that may contain videos
public struct Article: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: String
    public let title: String
    public let publicationDate: Date?
    public let author: String?
    public let excerpt: String?
    public let videoPositions: [VideoPosition]
    public let metadata: [String: String]
    public let discoveredAt: Date
    
    public init(
        id: UUID = UUID(),
        url: String,
        title: String,
        publicationDate: Date? = nil,
        author: String? = nil,
        excerpt: String? = nil,
        videoPositions: [VideoPosition] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.publicationDate = publicationDate
        self.author = author
        self.excerpt = excerpt
        self.videoPositions = videoPositions
        self.metadata = metadata
        self.discoveredAt = Date()
    }
}

/// Represents the position of a video within an article
public struct VideoPosition: Codable, Equatable, Hashable, Sendable {
    public let videoId: UUID
    public let positionInArticle: Int
    public let context: String?
    public let elementInfo: [String: String]
    
    public init(videoId: UUID, positionInArticle: Int, context: String? = nil, elementInfo: [String: String] = [:]) {
        self.videoId = videoId
        self.positionInArticle = positionInArticle
        self.context = context
        self.elementInfo = elementInfo
    }
}

/// Represents the overall site structure and analysis results
public struct SiteAnalysis: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let targetUrl: String
    public let siteUrl: String
    public let videos: [Video]
    public let articles: [Article]
    public let videoUrls: [VideoUrlDetail]
    public let analysisDate: Date
    public let processingTime: TimeInterval
    public let errorLog: [String]
    
    public init(
        id: UUID = UUID(),
        targetUrl: String,
        siteUrl: String,
        videos: [Video] = [],
        articles: [Article] = [],
        videoUrls: [VideoUrlDetail] = [],
        processingTime: TimeInterval = 0,
        errorLog: [String] = []
    ) {
        self.id = id
        self.targetUrl = targetUrl
        self.siteUrl = siteUrl
        self.videos = videos
        self.articles = articles
        self.videoUrls = videoUrls
        self.analysisDate = Date()
        self.processingTime = processingTime
        self.errorLog = errorLog
    }
}

/// Represents detailed information about a video URL
public struct VideoUrlDetail: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let video: Video
    public let originalUrl: String
    public let resolvedUrl: String?
    public let fileSize: Int64?
    public let accessibility: AccessibilityInfo
    public let relatedArticles: [UUID]
    
    public init(
        id: UUID = UUID(),
        video: Video,
        originalUrl: String,
        resolvedUrl: String? = nil,
        fileSize: Int64? = nil,
        accessibility: AccessibilityInfo = AccessibilityInfo(),
        relatedArticles: [UUID] = []
    ) {
        self.id = id
        self.video = video
        self.originalUrl = originalUrl
        self.resolvedUrl = resolvedUrl
        self.fileSize = fileSize
        self.accessibility = accessibility
        self.relatedArticles = relatedArticles
    }
}

/// Represents accessibility and technical information about a video
public struct AccessibilityInfo: Codable, Equatable, Hashable, Sendable {
    public let isAccessible: Bool
    public let requiresAuthentication: Bool
    public let blockedRegions: [String]
    public let supportedFormats: [VideoFormat]
    public let streamingInfo: StreamingInfo?
    
    public init(
        isAccessible: Bool = true,
        requiresAuthentication: Bool = false,
        blockedRegions: [String] = [],
        supportedFormats: [VideoFormat] = [],
        streamingInfo: StreamingInfo? = nil
    ) {
        self.isAccessible = isAccessible
        self.requiresAuthentication = requiresAuthentication
        self.blockedRegions = blockedRegions
        self.supportedFormats = supportedFormats
        self.streamingInfo = streamingInfo
    }
}

////** Represents streaming information for video content */
public struct StreamingInfo: Codable, Equatable, Hashable, Sendable {
    public let streamingType: StreamingType
    public let qualityOptions: [QualityOption]
    public let subtitleTracks: [SubtitleTrack]
    public let audioTracks: [AudioTrack]
    
    public init(
        streamingType: StreamingType,
        qualityOptions: [QualityOption] = [],
        subtitleTracks: [SubtitleTrack] = [],
        audioTracks: [AudioTrack] = []
    ) {
        self.streamingType = streamingType
        self.qualityOptions = qualityOptions
        self.subtitleTracks = subtitleTracks
        self.audioTracks = audioTracks
    }
}

/// Represents the type of streaming
public enum StreamingType: String, Codable, CaseIterable, Sendable {
    case progressive = "progressive"
    case hls = "hls"
    case dash = "dash"
    case rtmp = "rtmp"
    case unknown = "unknown"
}

/// Represents quality options for streaming video
public struct QualityOption: Codable, Equatable, Hashable, Sendable {
    public let resolution: String
    public let bitrate: Int
    public let codec: String
    public let url: String?
    
    public init(resolution: String, bitrate: Int, codec: String, url: String? = nil) {
        self.resolution = resolution
        self.bitrate = bitrate
        self.codec = codec
        self.url = url
    }
}

/// Represents subtitle tracks
public struct SubtitleTrack: Codable, Equatable, Hashable, Sendable {
    public let language: String
    public let label: String
    public let url: String
    
    public init(language: String, label: String, url: String) {
        self.language = language
        self.label = label
        self.url = url
    }
}

/// Represents audio tracks
public struct AudioTrack: Codable, Equatable, Hashable, Sendable {
    public let language: String
    public let label: String
    public let channelConfiguration: String
    
    public init(language: String, label: String, channelConfiguration: String) {
        self.language = language
        self.label = label
        self.channelConfiguration = channelConfiguration
    }
}