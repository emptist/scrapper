import Foundation

/// Protocol for ViewModel functionality
@MainActor public protocol ViewModel: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func handle(_ action: Action)
}

/// State for the main analyzer ViewModel
public struct AnalyzerViewModelState {
    public var isAnalyzing: Bool
    public var analysisResult: SiteAnalysis?
    public var errorMessage: String?
    public var progressMessage: String
    public var exportProgress: Double
    
    public init() {
        self.isAnalyzing = false
        self.analysisResult = nil
        self.errorMessage = nil
        self.progressMessage = ""
        self.exportProgress = 0.0
    }
}

/// Actions for the analyzer ViewModel
public enum AnalyzerViewModelAction {
    case startAnalysis(String)
    case exportAnalysis(ExportFormat)
    case clearResults
    case showError(String)
    case updateProgress(String)
}

/// ViewModel for the main video analyzer interface
@MainActor public class AnalyzerViewModel: ViewModel {
    private let videoAnalyzer: VideoAnalyzerEngine
    private let logger: Logging
    
    @Published public var state: AnalyzerViewModelState
    
    public init(videoAnalyzer: VideoAnalyzerEngine, logger: Logging = DefaultLogger()) {
        self.videoAnalyzer = videoAnalyzer
        self.logger = logger
        self.state = AnalyzerViewModelState()
    }
    
    public func handle(_ action: AnalyzerViewModelAction) {
        switch action {
        case .startAnalysis(let url):
            // Direct state updates on MainActor
            state.isAnalyzing = true
            state.progressMessage = "Validating URL..."
            state.errorMessage = nil
            
            // Use regular Task since we're in an actor-isolated context
            Task {
                await performAnalysis(url: url)
            }
            
        case .exportAnalysis(let format):
            guard let analysis = state.analysisResult else {
                state.errorMessage = "No analysis results to export"
                return
            }
            
            // Direct state updates on MainActor
            state.progressMessage = "Exporting results in \(format.rawValue) format..."
            
            // Capture necessary values
            let analysisCopy = analysis
            let formatCopy = format
            
            // Use regular Task since we're in an actor-isolated context
            Task {
                await performExport(
                    analysis: analysisCopy,
                    format: formatCopy
                )
            }
            
        case .clearResults:
            // Direct state update on MainActor
            state = AnalyzerViewModelState()
            
        case .showError(let message):
            // Direct state updates on MainActor
            state.errorMessage = message
            state.isAnalyzing = false
            state.progressMessage = ""
            
        case .updateProgress(let message):
            // Direct state update on MainActor
            state.progressMessage = message
        }
    }
    
    // MARK: - Private Static Methods
    
    private func performAnalysis(url: String) async {
        logger.info("Starting analysis for URL: \(url)")
        
        // Update progress
        await MainActor.run {
            state.progressMessage = "Analyzing video content..."
        }
        
        do {
            let analyzer = VideoAnalyzer()
            let result = try await analyzer.analyze(url: url)
            
            // Update state on main actor
            await MainActor.run {
                state.analysisResult = result
                state.progressMessage = "Analysis completed successfully"
                state.isAnalyzing = false
                
                if !result.errorLog.isEmpty {
                    logger.warning("Analysis completed with errors: \(result.errorLog)")
                }
            }
        } catch {
            let errorMsg = error.localizedDescription
            logger.error("Analysis failed: \(errorMsg)")
            
            // Handle errors on main actor
            await MainActor.run {
                state.errorMessage = errorMsg
                state.isAnalyzing = false
            }
        }
    }
    
    private func performExport(analysis: SiteAnalysis, format: ExportFormat) async {
        do {
            // Capture format before passing to non-isolated method
            let formatCopy = format
            let analyzer = VideoAnalyzer()
            let data = try await analyzer.export(analysis, format: formatCopy)
            
            // Capture necessary values before MainActor.run
            let formatRawValue = formatCopy.rawValue
            
            // Update state and write to file
            await MainActor.run {
                defer {
                    state.exportProgress = 0.0
                }
                
                do {
                    state.exportProgress = 1.0
                    
                    // Save to file
                    let filename = "video_analysis_\(Date().timeIntervalSince1970).\(formatRawValue)"
                    let fileURL = URL(fileURLWithPath: "/tmp/\(filename)")
                    try data.write(to: fileURL)
                    
                    state.progressMessage = "Export completed: \(filename)"
                } catch {
                    let errorMsg = error.localizedDescription
                    logger.error("File write failed: \(errorMsg)")
                    state.errorMessage = "Export failed: \(errorMsg)"
                }
            }
        } catch {
            let errorMessage = error.localizedDescription
            logger.error("Export failed: \(errorMessage)")
            
            // Handle errors on main actor
            await MainActor.run {
                state.errorMessage = "Export failed: \(errorMessage)"
                state.exportProgress = 0.0
            }
        }
    }
}