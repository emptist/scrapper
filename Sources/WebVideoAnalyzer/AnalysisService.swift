import Foundation
import VideoAnalyzerCore

/// Service responsible for handling all video analysis operations
class AnalysisService {
    private let logger: DefaultLogger
    
    /// Initializes the analysis service with a logger
    /// - Parameter logger: The logger instance for logging messages
    init(logger: DefaultLogger) {
        self.logger = logger
    }
    
    /// Performs analysis on a single URL
    func performAnalysis(url: String) async {
        logger.info("Starting analysis for: \(url)")
        
        do {
            let analyzer = VideoAnalyzer()
            let analysis = try await analyzer.analyze(url: url)
            
            // Export results in both formats
            let jsonData = try await analyzer.export(analysis, format: .json)
            let htmlData = try await analyzer.export(analysis, format: .html)
            
            // Save files
            let timestamp = Int(Date().timeIntervalSince1970)
            let jsonFileName = "/tmp/video_analysis_\(timestamp).json"
            let htmlFileName = "/tmp/video_analysis_\(timestamp).html"
            
            try jsonData.write(to: URL(fileURLWithPath: jsonFileName))
            try htmlData.write(to: URL(fileURLWithPath: htmlFileName))
            
            // Print summary
            print("\n=== Analysis Summary ===")
            print("URL: \(analysis.targetUrl)")
            print("Site: \(analysis.siteUrl)")
            print("Processing Time: \(String(format: "%.2f", analysis.processingTime)) seconds")
            print("Videos Found: \(analysis.videos.count)")
            print("Articles Found: \(analysis.articles.count)")
            print("Video URL Details: \(analysis.videoUrls.count)")
            
            if !analysis.errorLog.isEmpty {
                print("Errors: \(analysis.errorLog.count)")
                for error in analysis.errorLog {
                    print("  - \(error)")
                }
            }
            
            print("\nResults exported to:")
            print("  JSON: \(jsonFileName)")
            print("  HTML: \(htmlFileName)")
            
            // Display video details
            if !analysis.videos.isEmpty {
                print("\n=== Video Details ===")
                for (index, video) in analysis.videos.enumerated() {
                    print("\n\(index + 1). \(video.title ?? "Untitled Video")")
                    print("   URL: \(video.url)")
                    print("   Format: \(video.format.rawValue)")
                    print("   Resolution: \(video.resolution ?? "Unknown")")
                    print("   Embed Type: \(video.embedType.rawValue)")
                    print("   Hosting: \(video.hostingSource)")
                    if let duration = video.duration {
                        print("   Duration: \(Int(duration)) seconds")
                    }
                }
            }
            
            // Display article details
            if !analysis.articles.isEmpty {
                print("\n=== Articles with Videos ===")
                for (index, article) in analysis.articles.enumerated() {
                    print("\n\(index + 1). \(article.title)")
                    print("   URL: \(article.url)")
                    if let author = article.author {
                        print("   Author: \(author)")
                    }
                    if let date = article.publicationDate {
                        print("   Published: \(date)")
                    }
                    print("   Videos in Article: \(article.videoPositions.count)")
                    if let excerpt = article.excerpt {
                        print("   Excerpt: \(excerpt)")
                    }
                }
            }
            
        } catch {
            logger.error("Analysis failed: \(error.localizedDescription)")
            print("Analysis failed: \(error.localizedDescription)")
        }
    }
    
    /// Performs batch analysis on URLs from a file
    func performBatchAnalysis(filePath: String) async {
        logger.info("Starting batch analysis from file: \(filePath)")
        
        do {
            let fileContent = try String(contentsOfFile: filePath)
            let urls = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            guard !urls.isEmpty else {
                print("No URLs found in file: \(filePath)")
                return
            }
            
            print("Found \(urls.count) URLs to analyze")
            
            let analyzer = VideoAnalyzer()
            let analyses = try await analyzer.analyze(urls: urls)
            
            // Process and save results
            var totalVideos = 0
            var totalArticles = 0
            
            for analysis in analyses {
                totalVideos += analysis.videos.count
                totalArticles += analysis.articles.count
            }
            
            let timestamp = Int(Date().timeIntervalSince1970)
            let summaryFileName = "/tmp/batch_analysis_summary_\(timestamp).json"
            let detailedFileName = "/tmp/batch_analysis_detailed_\(timestamp).json"
            
            // Save summary
            let summary: [String: Any] = [
                "totalUrls": analyses.count,
                "totalVideos": totalVideos,
                "totalArticles": totalArticles,
                "analyses": analyses.map { analysis in
                    [
                        "url": analysis.targetUrl,
                        "videos": analysis.videos.count,
                        "articles": analysis.articles.count,
                        "processingTime": analysis.processingTime,
                        "errors": analysis.errorLog
                    ]
                }
            ]
            
            let summaryData = try JSONSerialization.data(withJSONObject: summary, options: .prettyPrinted)
            try summaryData.write(to: URL(fileURLWithPath: summaryFileName))
            
            // Save detailed results
            let detailedData = try JSONEncoder().encode(analyses)
            try detailedData.write(to: URL(fileURLWithPath: detailedFileName))
            
            print("\n=== Batch Analysis Summary ===")
            print("Total URLs Analyzed: \(analyses.count)")
            print("Total Videos Found: \(totalVideos)")
            print("Total Articles Found: \(totalArticles)")
            print("Average Processing Time: \(analyses.map { $0.processingTime }.reduce(0, +) / Double(analyses.count)) seconds")
            
            print("\nResults exported to:")
            print("  Summary: \(summaryFileName)")
            print("  Detailed: \(detailedFileName)")
            
        } catch {
            logger.error("Batch analysis failed: \(error.localizedDescription)")
            print("Batch analysis failed: \(error.localizedDescription)")
        }
    }
    
    /// Validates a URL
    func performValidation(url: String) async {
        logger.info("Validating URL: \(url)")
        
        do {
            let analyzer = VideoAnalyzer()
            let validation = try await analyzer.validate(url: url)
            
            if validation.isValid {
                print("✅ URL is valid and accessible: \(url)")
            } else {
                print("❌ URL validation failed: \(url)")
                if let errorMessage = validation.errorMessage {
                    print("Error: \(errorMessage)")
                }
            }
            
        } catch {
            logger.error("Validation failed: \(error.localizedDescription)")
            print("Validation failed: \(error.localizedDescription)")
        }
    }
}