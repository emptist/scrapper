import Foundation

/// Protocol for ViewModel functionality
public protocol ViewModel: ObservableObject {
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
public class AnalyzerViewModel: ViewModel {
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
            Task {
                await performAnalysis(url)
            }
            
        case .exportAnalysis(let format):
            Task {
                await performExport(format)
            }
            
        case .clearResults:
            state = AnalyzerViewModelState()
            
        case .showError(let message):
            state.errorMessage = message
            state.isAnalyzing = false
            state.progressMessage = ""
            
        case .updateProgress(let message):
            state.progressMessage = message
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func performAnalysis(_ url: String) async {
        logger.info("Starting analysis from ViewModel for URL: \(url)")
        state.isAnalyzing = true
        state.progressMessage = "Validating URL..."
        state.errorMessage = nil
        
        do {
            let analysis = try await videoAnalyzer.analyze(url: url)
            state.analysisResult = analysis
            state.progressMessage = "Analysis completed successfully"
            
            if !analysis.errorLog.isEmpty {
                logger.warning("Analysis completed with errors: \(analysis.errorLog)")
            }
            
        } catch {
            logger.error("Analysis failed: \(error.localizedDescription)")
            state.errorMessage = error.localizedDescription
        }
        
        state.isAnalyzing = false
    }
    
    @MainActor
    private func performExport(_ format: ExportFormat) async {
        guard let analysis = state.analysisResult else {
            state.errorMessage = "No analysis results to export"
            return
        }
        
        state.progressMessage = "Exporting results in \(format.rawValue) format..."
        
        do {
            let data = try await videoAnalyzer.export(analysis, format: format)
            state.exportProgress = 1.0
            
            // Save to file (in a real app, this would use file picker)
            let filename = "video_analysis_\(Date().timeIntervalSince1970).\(format.rawValue)"
            let fileURL = URL(fileURLWithPath: "/tmp/\(filename)")
            try data.write(to: fileURL)
            
            state.progressMessage = "Export completed: \(filename)"
            
        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            state.errorMessage = "Export failed: \(error.localizedDescription)"
        }
        
        state.exportProgress = 0.0
    }
}