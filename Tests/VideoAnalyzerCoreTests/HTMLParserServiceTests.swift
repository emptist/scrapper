import Foundation
import XCTest
@testable import VideoAnalyzerCore

final class HTMLParserServiceTests: XCTestCase {
    
    func testParseHTMLWithVideos() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <h1>Test Article</h1>
            <video controls width="640">
                <source src="video.mp4" type="video/mp4">
                <source src="video.webm" type="video/webm">
            </video>
            <iframe src="https://www.youtube.com/embed/abc123" width="560" height="315"></iframe>
        </body>
        </html>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        XCTAssertGreaterThanOrEqual(parsed.videos.count, 2)
        XCTAssertGreaterThanOrEqual(parsed.articles.count, 1)
        
        let videoElement = parsed.videos.first { $0.url.contains("video.mp4") }
        XCTAssertNotNil(videoElement)
        XCTAssertEqual(videoElement?.embedType, .html5)
    }
    
    @Test("Extract video metadata from HTML5 video tag")
    func testExtractVideoMetadata() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <video controls width="1280" height="720" poster="thumbnail.jpg">
            <source src="test.mp4" type="video/mp4" quality="1080p">
            <source src="test.webm" type="video/webm">
            <track kind="subtitles" src="subtitles.vtt" srclang="en" label="English">
        </video>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        let video = parsed.videos.first { $0.url.contains("test.mp4") }
        
        XCTAssertEqual(video?.format, .mp4)
        XCTAssertEqual(video?.resolution, "1280x720")
        XCTAssertEqual(video?.thumbnailUrl, "thumbnail.jpg")
        XCTAssertEqual(video?.subtitleTracks?.count, 1)
    }
    
    @Test("Detect embedded videos from iframe sources")
    func testDetectIframeVideos() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <div class="video-container">
            <iframe src="https://player.vimeo.com/video/123456789" 
                    width="640" height="360" frameborder="0" 
                    allow="autoplay; fullscreen; picture-in-picture">
            </iframe>
        </div>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        let vimeoVideo = parsed.videos.first { $0.url.contains("vimeo.com") }
        XCTAssertNotNil(vimeoVideo)
        XCTAssertEqual(vimeoVideo?.embedType, .iframe)
        XCTAssertEqual(vimeoVideo?.hostingSource, "Vimeo")
    }
    
    @Test("Extract articles with video content")
    func testExtractArticlesWithVideos() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <article>
            <header>
                <h1>Medical Imaging Techniques</h1>
                <time datetime="2023-12-01">December 1, 2023</time>
                <author>Dr. Smith</author>
            </header>
            <p>This article discusses various ultrasound imaging techniques.</p>
            <video controls>
                <source src="ultrasound.mp4" type="video/mp4">
            </video>
            <p>Additional content about the video follows.</p>
        </article>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        XCTAssertEqual(parsed.articles.count, 1)
        let article = parsed.articles.first
        XCTAssertEqual(article?.title, "Medical Imaging Techniques")
        XCTAssertEqual(article?.author, "Dr. Smith")
        XCTAssertEqual(article?.videoPositions.count, 1)
        XCTAssertTrue(article?.videoPositions.first?.videoURL.contains("ultrasound.mp4") ?? false)
    }
    
    @Test("Resolve relative URLs")
    func testResolveRelativeURLs() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <video controls>
            <source src="/videos/sample.mp4" type="video/mp4">
        </video>
        <iframe src="../media/embedded.html"></iframe>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com/articles/page")
        
        let video = parsed.videos.first
        XCTAssertTrue(video?.url.hasPrefix("https://example.com/videos/sample.mp4") ?? false)
        
        let iframe = parsed.videos.first { $0.embedType == .iframe }
        XCTAssertTrue(iframe?.url.hasPrefix("https://example.com/media/embedded.html") ?? false)
    }
    
    @Test("Handle JavaScript-rendered video content")
    func testHandleJavaScriptVideos() async throws {
        let htmlParser = HTMLParserService()
        let html = """
        <div id="video-container" data-video-id="js123"></div>
        <script>
            // Simulated JavaScript content
            const container = document.getElementById('video-container');
            container.innerHTML = '<video src="dynamic.mp4" controls></video>';
        </script>
        """
        
        let parsed = try await htmlParser.parse(html: html, baseURL: "https://example.com")
        
        // Should detect the JavaScript-rendered video
        let jsVideo = parsed.videos.first { $0.url.contains("dynamic.mp4") }
        XCTAssertNotNil(jsVideo)
        XCTAssertEqual(jsVideo?.embedType, .javascriptRendered)
    }
}