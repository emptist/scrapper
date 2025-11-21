import SwiftUI
import VideoAnalyzerCore
import Foundation

/// Main application entry point conforming to SwiftUI App protocol
@main
struct VideoFinderApp: App {
    // Create necessary dependencies
    private let logger = DefaultLogger()
    private let analysisService: AnalysisService
    private let commandLineHandler: CommandLineHandler
    private let shouldShowUI: Bool
    
    // Default initialiser
    init() {
        // Check if running with command-line arguments
        let arguments = CommandLine.arguments
        shouldShowUI = arguments.count <= 1 || (arguments.count > 1 && (arguments[1] == "--gui" || arguments[1] == "-g"))
        
        // Initialise services with dependencies
        self.analysisService = AnalysisService(logger: logger)
        self.commandLineHandler = CommandLineHandler(logger: logger, analysisService: analysisService)
        
        // Handle command-line arguments if UI shouldn't be shown
        if !shouldShowUI {
            let handler = commandLineHandler
            Task {
                await handler.handleCommandLineArguments(arguments)
                // Exit after handling CLI arguments
                exit(EXIT_SUCCESS)
            }
        }
    }
    
    // Create and configure the main scene
    var body: some Scene {
        WindowGroup {
            // Only show UI if not running in CLI mode
            if shouldShowUI {
                ContentView()
            } else {
                // Empty view that will never be displayed
                EmptyView()
            }
        }
        // Set a more appropriate title for the macOS app
    }
}
