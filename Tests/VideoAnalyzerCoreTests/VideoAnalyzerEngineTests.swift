import Foundation
import XCTest
@testable import VideoAnalyzerCore

final class VideoAnalyzerEngineTests: XCTestCase {
    
    func testAnalyzeSingleURL() async throws {
        let httpClient = DefaultHTTPClient()
        let logger = DefaultLogger()
        let analyzer = VideoAnalyzerEngine(
            httpClient: httpClient,
            logger: logger,
            duplicateDetector: DefaultDuplicateDetector()
        )
        
        // Test with a simple HTML page containing video
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Video Page</title></head>
        <body>
            <article>
                <h1>Sample Medical Case</h1>
                <p>Description of the medical case study.</p>
                <video controls width="640">
                    <source src="sample.mp4" type="video/mp4">
                    <track kind="subtitles" src="subtitles.vtt" srclang="en">
                </video>
            </article>
        </body>
        </html>
        """
        
        // Note: In real implementation, this would fetch from actual URL
        // For testing, we're testing the parsing logic
        
        let parsedHTML = try await HTMLParserService().parse(html: testHTML, baseURL: "https://example.com")
        
        XCTAssertGreaterThan(parsedHTML.videos.count, 0)
        XCTAssertGreaterThan(parsedHTML.articles.count, 0)
        
        let video = parsedHTML.videos.first
        XCTAssertEqual(video?.format, .mp4)
        XCTAssertEqual(video?.embedType, .html5)
        
        let article = parsedHTML.articles.first
        XCTAssertEqual(article?.title, "Sample Medical Case")
        XCTAssertEqual(article?.videoPositions.count, 1)
    }
    
    @Test("Handle multiple video formats in single HTML5 video element")
    func testHandleMultipleVideoFormats() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <video controls poster="thumb.jpg">
            <source src="video.webm" type="video/webm">
            <source src="video.mp4" type="video/mp4">
            <source src="video.ogg" type="video/ogg">
            <track kind="subtitles" src="en.vtt" srclang="en" label="English">
            <track kind="subtitles" src="es.vtt" srclang="es" label="Spanish">
        </video>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        XCTAssertGreaterThanOrEqual(parsed.videos.count, 3) // Multiple source formats
        
        let mp4Video = parsed.videos.first { $0.url.contains("video.mp4") }
        XCTAssertNotNil(mp4Video)
        XCTAssertEqual(mp4Video?.format, .mp4)
        XCTAssertEqual(mp4Video?.thumbnailUrl, "thumb.jpg")
        XCTAssertEqual(mp4Video?.subtitleTracks?.count, 2)
    }
    
    @Test("Process YouTube iframe embeds")
    func testProcessYouTubeEmbeds() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <div class="video-wrapper">
            <iframe width="560" height="315" 
                    src="https://www.youtube.com/embed/dQw4w9WgXcQ" 
                    title="YouTube video player" 
                    frameborder="0" 
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
                    allowfullscreen>
            </iframe>
        </div>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        let youtubeVideo = parsed.videos.first { $0.url.contains("youtube.com") }
        XCTAssertNotNil(youtubeVideo)
        XCTAssertEqual(youtubeVideo?.embedType, .iframe)
        XCTAssertEqual(youtubeVideo?.hostingSource, "YouTube")
        XCTAssertNotNil(youtubeVideo?.videoId) // Should extract video ID
    }
    
    @Test("Detect medical ultrasound video content")
    func testDetectMedicalUltrasoundContent() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <article>
            <header>
                <h1>Appendicitis Case Study</h1>
                <time datetime="2023-11-15">November 15, 2023</time>
                <author>Dr. Medical Student</author>
            </header>
            <p>This case study demonstrates ultrasound imaging techniques for diagnosing appendicitis.</p>
            <video controls width="640" poster="ultrasound_thumb.jpg">
                <source src="ultrasound_appendicitis.mp4" type="video/mp4">
                <source src="ultrasound_appendicitis.webm" type="video/webm">
            </video>
            <p>The ultrasound shows characteristic signs of appendicitis including wall thickening and fluid collection.</p>
            <iframe src="https://www.youtube.com/embed/medical123" width="560" height="315"></iframe>
        </article>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://ultrasoundcases.info")
        
        XCTAssertEqual(parsed.articles.count, 1)
        
        let article = parsed.articles.first
        XCTAssertTrue(article?.title.contains("Appendicitis") ?? false)
        XCTAssertNotNil(article?.author)
        XCTAssertEqual(article?.videoPositions.count, 2) // Video element + YouTube iframe
        
        let ultrasoundVideo = parsed.videos.first { $0.url.contains("ultrasound") }
        XCTAssertEqual(ultrasoundVideo?.thumbnailUrl, "ultrasound_thumb.jpg")
        XCTAssertEqual(ultrasoundVideo?.embedType, .html5)
    }
    
    @Test("Export analysis results in JSON format")
    func testExportResultsJSON() async throws {
        let analyzer = VideoAnalyzer()
        let testAnalysis = SiteAnalysis(
            targetUrl: "https://example.com/test",
            siteUrl: "https://example.com",
            videos: [
                Video(
                    id: "video1",
                    url: "https://example.com/video1.mp4",
                    title: "Test Video",
                    format: .mp4,
                    resolution: "1920x1080",
                    duration: 120.0,
                    hostingSource: "Local",
                    embedType: .html5,
                    thumbnailUrl: "thumb.jpg",
                    discoveredAt: Date()
                )
            ],
            articles: [
                Article(
                    url: "https://example.com/article",
                    title: "Test Article",
                    author: "Test Author",
                    publicationDate: Date(),
                    excerpt: "Test excerpt",
                    videoPositions: [
                        VideoPosition(
                            videoURL: "https://example.com/video1.mp4",
                            positionInText: 150,
                            contextBefore: "Video content follows:",
                            contextAfter: "This demonstrates the technique."
                        )
                    ]
                )
            ],
            videoUrls: [
                VideoUrlDetail(
                    url: "https://example.com/video1.mp4",
                    format: "mp4",
                    resolution: "1920x1080",
                    hostingSource: "Local"
                )
            ],
            processingTime: 1.5,
            errorLog: []
        )
        
        let jsonData = try await analyzer.export(testAnalysis, format: .json)
        
        XCTAssertGreaterThan(jsonData.count, 0)
        
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertTrue(jsonString?.contains("Test Video") ?? false)
        XCTAssertTrue(jsonString?.contains("Test Article") ?? false)
        XCTAssertTrue(jsonString?.contains("mp4") ?? false)
    }
    
    @Test("Export analysis results in HTML format")
    func testExportResultsHTML() async throws {
        let analyzer = VideoAnalyzer()
        let testAnalysis = SiteAnalysis(
            targetUrl: "https://example.com/test",
            siteUrl: "https://example.com",
            videos: [
                Video(
                    id: "video1",
                    url: "https://example.com/video1.mp4",
                    title: "Ultrasound Demonstration",
                    format: .mp4,
                    resolution: "1280x720",
                    duration: 180.0,
                    hostingSource: "Local",
                    embedType: .html5,
                    thumbnailUrl: "ultrasound_thumb.jpg",
                    discoveredAt: Date()
                )
            ],
            articles: [
                Article(
                    url: "https://example.com/case-study",
                    title: "Medical Case Study: Ultrasound Imaging",
                    author: "Dr. Researcher",
                    publicationDate: Date(timeIntervalSince1970: 1700000000),
                    excerpt: "This case study demonstrates advanced ultrasound imaging techniques for medical diagnosis.",
                    videoPositions: [
                        VideoPosition(
                            videoURL: "https://example.com/video1.mp4",
                            positionInText: 200,
                            contextBefore: "The following ultrasound demonstrates:",
                            contextAfter: "Note the key diagnostic features."
                        )
                    ]
                )
            ],
            videoUrls: [
                VideoUrlDetail(
                    url: "https://example.com/video1.mp4",
                    format: "mp4",
                    resolution: "1280x720",
                    hostingSource: "Local"
                )
            ],
            processingTime: 2.3,
            errorLog: []
        )
        
        let htmlData = try await analyzer.export(testAnalysis, format: .html)
        
        XCTAssertGreaterThan(htmlData.count, 0)
        
        let htmlString = String(data: htmlData, encoding: .utf8)
        XCTAssertTrue(htmlString?.contains("Ultrasound Demonstration") ?? false)
        XCTAssertTrue(htmlString?.contains("Medical Case Study") ?? false)
        XCTAssertTrue(htmlString?.contains("<table>") ?? false)
        XCTAssertTrue(htmlString?.contains("Dr. Researcher") ?? false)
    }
    
    @Test("Handle errors gracefully")
    func testHandleErrors() async throws {
        let analyzer = VideoAnalyzer()
        let testAnalysis = SiteAnalysis(
            targetUrl: "https://example.com/error-test",
            siteUrl: "https://example.com",
            videos: [],
            articles: [],
            videoUrls: [],
            processingTime: 0.1,
            errorLog: [
                "Failed to fetch video metadata from https://example.com/video1.mp4",
                "Invalid video format detected in https://example.com/corrupted.mp4",
                "Access denied to https://protected-site.com/video.mp4"
            ]
        )
        
        XCTAssertFalse(testAnalysis.errorLog.isEmpty)
        XCTAssertEqual(testAnalysis.errorLog.count, 3)
        
        let jsonData = try await analyzer.export(testAnalysis, format: .json)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        XCTAssertTrue(jsonString?.contains("Failed to fetch video metadata") ?? false)
        XCTAssertTrue(jsonString?.contains("Access denied") ?? false)
    }
    
    @Test("Remove duplicate videos")
    func testRemoveDuplicateVideos() async throws {
        let detector = DefaultDuplicateDetector()
        
        var videos = [
            Video(
                id: "video1",
                url: "https://example.com/video1.mp4",
                title: "Same Video",
                format: .mp4,
                hostingSource: "Local",
                embedType: .html5,
                discoveredAt: Date()
            ),
            Video(
                id: "video1", // Same ID
                url: "https://example.com/video1.mp4", // Same URL
                title: "Same Video",
                format: .mp4,
                hostingSource: "Local",
                embedType: .html5,
                discoveredAt: Date()
            ),
            Video(
                id: "video2",
                url: "https://example.com/video2.mp4",
                title: "Different Video",
                format: .mp4,
                hostingSource: "Local",
                embedType: .html5,
                discoveredAt: Date()
            )
        ]
        
        let uniqueVideos = await detector.removeDuplicates(videos: &videos)
        
        XCTAssertEqual(uniqueVideos.count, 2) // Should remove one duplicate
        XCTAssertEqual(videos.count, 2)
    }
}