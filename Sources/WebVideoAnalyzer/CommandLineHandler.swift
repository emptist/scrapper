import Foundation
import VideoAnalyzerCore

/// Handles command-line operations for the Web Video Analyzer
class CommandLineHandler {
    private let logger: DefaultLogger
    private let analysisService: AnalysisService
    
    /// Initializes the command-line handler with required dependencies
    /// - Parameters:
    ///   - logger: The logger instance for logging messages
    ///   - analysisService: The analysis service for performing video analysis
    init(logger: DefaultLogger, analysisService: AnalysisService) {
        self.logger = logger
        self.analysisService = analysisService
    }
    
    /// Handles command-line arguments for the analyzer
    func handleCommandLineArguments(_ arguments: [String]) async {
        guard arguments.count > 1 else {
            printUsage()
            return
        }
        
        let command = arguments[1]
        
        switch command {
        case "analyze":
            if arguments.count < 3 {
                print("Error: URL required for analyze command")
                printUsage()
                return
            }
            
            let url = arguments[2]
            await analysisService.performAnalysis(url: url)
            
        case "batch":
            if arguments.count < 3 {
                print("Error: File path required for batch command")
                printUsage()
                return
            }
            
            let filePath = arguments[2]
            await analysisService.performBatchAnalysis(filePath: filePath)
            
        case "validate":
            if arguments.count < 3 {
                print("Error: URL required for validate command")
                printUsage()
                return
            }
            
            let url = arguments[2]
            await analysisService.performValidation(url: url)
            
        case "--help", "-h":
            printUsage()
            
        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }
    
    /// Prints usage information for command-line mode
    func printUsage() {
        print("""
        Web Video Analyzer - Comprehensive video content analysis tool
        
        Usage: WebVideoAnalyzer <command> [options]
        
        Commands:
          analyze <url>         Analyze a single URL for video content
          batch <file>          Analyze multiple URLs from a file
          validate <url>        Validate a URL before analysis
        
        Options:
          --help, -h           Show this help message
        
        Examples:
          WebVideoAnalyzer analyze https://www.ultrasoundcases.info/appendicitis-6737/
          WebVideoAnalyzer batch urls.txt
          WebVideoAnalyzer validate https://example.com
        
        Output files are saved to /tmp/ directory:
          - video_analysis_<timestamp>.json (JSON format)
          - video_analysis_<timestamp>.html (HTML format)
        """)
    }
}