import Foundation

/// Protocol for duplicate detection capabilities
public protocol DuplicateDetecting {
    func removeDuplicateVideos(_ videos: [Video]) -> [Video]
    func removeDuplicateArticles(_ articles: [Article]) -> [Article]
    func removeDuplicateVideoUrls(_ videoUrls: [VideoUrlDetail]) -> [VideoUrlDetail]
}

/// Default duplicate detector implementation
public class DefaultDuplicateDetector: DuplicateDetecting {
    
    public init() {}
    
    public func removeDuplicateVideos(_ videos: [Video]) -> [Video] {
        var seenIds = Set<UUID>()
        var seenUrls = Set<String>()
        var result: [Video] = []
        
        for video in videos {
            let urlString = video.url
            
            // Check if we've seen this video ID or URL before
            if seenIds.contains(video.id) || seenUrls.contains(urlString) {
                continue
            }
            
            seenIds.insert(video.id)
            seenUrls.insert(urlString)
            result.append(video)
        }
        
        return result
    }
    
    public func removeDuplicateArticles(_ articles: [Article]) -> [Article] {
        var seenIds = Set<UUID>()
        var seenUrls = Set<String>()
        var result: [Article] = []
        
        for article in articles {
            let urlString = article.url.absoluteString
            
            // Check if we've seen this article ID or URL before
            if seenIds.contains(article.id) || seenUrls.contains(urlString) {
                continue
            }
            
            seenIds.insert(article.id)
            seenUrls.insert(urlString)
            result.append(article)
        }
        
        return result
    }
    
    public func removeDuplicateVideoUrls(_ videoUrls: [VideoUrlDetail]) -> [VideoUrlDetail] {
        var seenIds = Set<UUID>()
        var seenUrls = Set<String>()
        var result: [VideoUrlDetail] = []
        
        for videoUrl in videoUrls {
            // Check if we've seen this video URL detail ID or URL before
            if seenIds.contains(videoUrl.id) || seenUrls.contains(videoUrl.originalUrl) {
                continue
            }
            
            seenIds.insert(videoUrl.id)
            seenUrls.insert(videoUrl.originalUrl)
            result.append(videoUrl)
        }
        
        return result
    }
}