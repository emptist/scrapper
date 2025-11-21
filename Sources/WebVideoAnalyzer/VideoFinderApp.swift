import SwiftUI
import VideoAnalyzerCore

/// Main application entry point conforming to SwiftUI App protocol
@main
struct VideoFinderApp: App {
    // Create necessary dependencies
    private let logger = DefaultLogger()
    private let analysisService: AnalysisService
    private let commandLineHandler: CommandLineHandler
    
    // Default initializer
    init() {
        // Initialize services with dependencies
        self.analysisService = AnalysisService(logger: logger)
        self.commandLineHandler = CommandLineHandler(logger: logger, analysisService: analysisService)
    }
    
    // Create and configure the main scene
    var body: some Scene {
        WindowGroup {
            // The app will primarily work as a command-line tool
            // but also provide a basic UI if launched as an app
            ContentView()
        }
    }
}
