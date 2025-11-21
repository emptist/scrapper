import Foundation
// Import VideoAnalyzerCore module properly
import VideoAnalyzerCore

/// Represents the result of an analysis operation, including saved file paths
struct AnalysisOperationResult {
    let analysis: SiteAnalysis
    let jsonFilePath: String
    let htmlFilePath: String

    init(analysis: SiteAnalysis, jsonFilePath: String, htmlFilePath: String) {
        self.analysis = analysis
        self.jsonFilePath = jsonFilePath
        self.htmlFilePath = htmlFilePath
    }
}

/// Represents the result of a batch analysis operation
struct BatchAnalysisResult {
    let analyses: [SiteAnalysis]
    let summaryFilePath: String
    let detailedFilePath: String
    let totalVideos: Int
    let totalArticles: Int
    let averageProcessingTime: Double

    init(analyses: [SiteAnalysis], summaryFilePath: String, detailedFilePath: String, totalVideos: Int, totalArticles: Int, averageProcessingTime: Double) {
        self.analyses = analyses
        self.summaryFilePath = summaryFilePath
        self.detailedFilePath = detailedFilePath
        self.totalVideos = totalVideos
        self.totalArticles = totalArticles
        self.averageProcessingTime = averageProcessingTime
    }
}

/// Service responsible for handling all video analysis operations
class AnalysisService {
    private let logger: DefaultLogger

    /// Initializes the analysis service with a logger
    /// - Parameter logger: The logger instance for logging messages
    init(logger: DefaultLogger) {
        self.logger = logger
    }

    /// Performs analysis on a single URL and returns the result
    /// - Parameter url: The URL to analyze
    /// - Returns: AnalysisOperationResult containing the analysis and saved file paths
    func performAnalysis(url: String) async throws -> AnalysisOperationResult {
        logger.info("Starting analysis for: \(url)")

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

        // Log results for CLI mode
        printAnalysisResultsToConsole(analysis: analysis, jsonPath: jsonFileName, htmlPath: htmlFileName)

        return AnalysisOperationResult(analysis: analysis, jsonFilePath: jsonFileName, htmlFilePath: htmlFileName)
    }

    /// Performs batch analysis on URLs from a file and returns the results
    /// - Parameter filePath: Path to the file containing URLs
    /// - Returns: BatchAnalysisResult containing all analyses and saved file paths
    func performBatchAnalysis(filePath: String) async throws -> BatchAnalysisResult {
        logger.info("Starting batch analysis from file: \(filePath)")

        let fileContent = try String(contentsOfFile: filePath)
        let urls = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !urls.isEmpty else {
            throw NSError(domain: "AnalysisService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No URLs found in file: \(filePath)"])
        }

        print("Found \(urls.count) URLs to analyze")

        let analyzer = VideoAnalyzer()
        let analyses = try await analyzer.analyze(urls: urls)

        // Process results
        var totalVideos = 0
        var totalArticles = 0

        for analysis in analyses {
            totalVideos += analysis.videos.count
            totalArticles += analysis.articles.count
        }

        let averageProcessingTime = analyses.map { $0.processingTime }.reduce(0, +) / Double(analyses.count)

        // Save results
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

        // Log results for CLI mode
        printBatchResultsToConsole(
            count: analyses.count,
            totalVideos: totalVideos,
            totalArticles: totalArticles,
            avgProcessingTime: averageProcessingTime,
            summaryPath: summaryFileName,
            detailedPath: detailedFileName
        )

        return BatchAnalysisResult(
            analyses: analyses,
            summaryFilePath: summaryFileName,
            detailedFilePath: detailedFileName,
            totalVideos: totalVideos,
            totalArticles: totalArticles,
            averageProcessingTime: averageProcessingTime
        )
    }

    /// Validates a URL and returns the validation result
    /// - Parameter url: The URL to validate
    /// - Returns: The validation result
    func performValidation(url: String) async throws -> ValidationResult {
        logger.info("Validating URL: \(url)")

        let analyzer = VideoAnalyzer()
        let validation = try await analyzer.validate(url: url)

        // Log results for CLI mode
        if validation.isValid {
            print("✅ URL is valid and accessible: \(url)")
        } else {
            print("❌ URL validation failed: \(url)")
            if let errorMessage = validation.errorMessage {
                print("Error: \(errorMessage)")
            }
        }

        return validation
    }

    /// Helper method to print analysis results to console for CLI mode
    private func printAnalysisResultsToConsole(analysis: SiteAnalysis, jsonPath: String, htmlPath: String) {
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
        print("  JSON: \(jsonPath)")
        print("  HTML: \(htmlPath)")

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
    }

    /// Helper method to print batch analysis results to console for CLI mode
    private func printBatchResultsToConsole(count: Int, totalVideos: Int, totalArticles: Int, avgProcessingTime: Double, summaryPath: String, detailedPath: String) {
        print("\n=== Batch Analysis Summary ===")
        print("Total URLs Analyzed: \(count)")
        print("Total Videos Found: \(totalVideos)")
        print("Total Articles Found: \(totalArticles)")
        print("Average Processing Time: \(String(format: "%.2f", avgProcessingTime)) seconds")

        print("\nResults exported to:")
        print("  Summary: \(summaryPath)")
        print("  Detailed: \(detailedPath)")
    }
}
