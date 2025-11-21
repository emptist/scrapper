import SwiftUI
import VideoAnalyzerCore
import Foundation

/// A view model for the ContentView to manage state and business logic
class ContentViewModel: ObservableObject {
    @Published var urlInput: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var isBatchMode: Bool = false
    @Published var batchFilePath: String = ""
    @Published var analysisResults: SiteAnalysis? = nil
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var selectedTab: Int = 0
    
    private let logger = DefaultLogger()
    private let analysisService: AnalysisService
    
    init() {
        self.analysisService = AnalysisService(logger: logger)
    }
    
    /// Analyze a single URL
    @MainActor
    func analyzeUrl() async {
        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a URL"
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let analyzer = VideoAnalyzer()
            let result = try await analyzer.analyze(url: urlInput)
            analysisResults = result
            successMessage = "Analysis completed successfully"
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }
        
        // Ensure we're not analyzing anymore
        isAnalyzing = false
    }
    
    /// Validate a URL
    @MainActor
    func validateUrl() async {
        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a URL"
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let analyzer = VideoAnalyzer()
            let validation = try await analyzer.validate(url: urlInput)
            
            if validation.isValid {
                successMessage = "✅ URL is valid and accessible"
            } else {
                errorMessage = "❌ URL validation failed: \(validation.errorMessage ?? "Unknown error")"
            }
        } catch {
            errorMessage = "Validation failed: \(error.localizedDescription)"
        }
        
        // Ensure we're not analyzing anymore
        isAnalyzing = false
    }
    
    /// Open file picker for batch analysis
    @MainActor
    func selectBatchFile() async {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.plainText]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            batchFilePath = openPanel.urls.first?.path ?? ""
        }
    }
    
    /// Perform batch analysis
    @MainActor
    func performBatchAnalysis() async {
        guard !batchFilePath.isEmpty else {
            errorMessage = "Please select a batch file"
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let analyzer = VideoAnalyzer()
            let fileContent = try String(contentsOfFile: batchFilePath)
            let urls = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            if urls.isEmpty {
                errorMessage = "No URLs found in the selected file"
                return
            }
            
            successMessage = "Analyzing \(urls.count) URLs..."
            let results = try await analyzer.analyze(urls: urls)
            
            // For batch mode, we'll just show the first result in detail
            // and provide a summary of all results
            if let firstResult = results.first {
                analysisResults = firstResult
            }
            
            successMessage = "Batch analysis completed: \(results.count) URLs analyzed, found \(results.reduce(0) { $0 + $1.videos.count }) videos"
        } catch {
            errorMessage = "Batch analysis failed: \(error.localizedDescription)"
        }
        
        // Ensure we're not analyzing anymore
        isAnalyzing = false
    }
}

/// Enhanced content view with interactive controls for the GUI version of the app
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showFileImporter = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedTab) {
                NavigationLink("Single URL Analysis", value: 0)
                NavigationLink("Batch Analysis", value: 1)
                NavigationLink("Results", value: 2)
            }
            .navigationTitle("Web Video Analyzer")
        } detail: {
            if viewModel.selectedTab == 0 {
                SingleUrlAnalysisView(viewModel: viewModel)
            } else if viewModel.selectedTab == 1 {
                BatchAnalysisView(viewModel: viewModel)
            } else {
                ResultsView(analysisResult: viewModel.analysisResults)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

/// View for single URL analysis functionality
struct SingleUrlAnalysisView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analyze a single URL for video content")
                .font(.title2)
                .padding(.bottom, 8)
            
            TextField("Enter URL", text: $viewModel.urlInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            HStack(spacing: 12) {
                Button(action: { Task { await viewModel.analyzeUrl() } }) {
                    Text("Analyze URL")
                }
                .disabled(viewModel.isAnalyzing || viewModel.urlInput.isEmpty)
                
                Button(action: { Task { await viewModel.validateUrl() } }) {
                    Text("Validate URL")
                }
                .disabled(viewModel.isAnalyzing || viewModel.urlInput.isEmpty)
            }
            .padding(.horizontal)
            
            if viewModel.isAnalyzing {
                ProgressView("Processing...")
                    .padding()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Single URL Analysis")
    }
}

/// View for batch analysis functionality
struct BatchAnalysisView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analyze multiple URLs from a text file")
                .font(.title2)
                .padding(.bottom, 8)
            
            HStack {
                Text(viewModel.batchFilePath.isEmpty ? "No file selected" : viewModel.batchFilePath)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
                Button(action: { Task { await viewModel.selectBatchFile() } }) {
                Text("Select File")
            }
                .disabled(viewModel.isAnalyzing)
            }
            .padding(.horizontal)
            
            Button(action: { Task { await viewModel.performBatchAnalysis() } }) {
                Text("Start Batch Analysis")
            }
            .disabled(viewModel.isAnalyzing || viewModel.batchFilePath.isEmpty)
            .padding(.horizontal)
            
            if viewModel.isAnalyzing {
                ProgressView("Processing...")
                    .padding()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Batch Analysis")
    }
}

/// View for displaying analysis results
struct ResultsView: View {
    let analysisResult: SiteAnalysis?
    
    var body: some View {
        ScrollView {
            if let result = analysisResult {
                VStack(alignment: .leading, spacing: 20) {
                    SummarySection(analysis: result)
                    VideosSection(videos: result.videos)
                    ArticlesSection(articles: result.articles)
                    
                    if !result.errorLog.isEmpty {
                        ErrorSection(errors: result.errorLog)
                    }
                }
                .padding()
            } else {
                VStack {
                    Text("No analysis results available")
                        .font(.title3)
                        .padding()
                    Text("Run an analysis first to see results here")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Analysis Results")
    }
}

/// Section showing analysis summary
struct SummarySection: View {
    let analysis: SiteAnalysis
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Analysis Summary")
                .font(.title3)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading) {
                Text("URL: \(analysis.targetUrl)")
                Text("Site: \(analysis.siteUrl)")
                Text("Processing Time: \(String(format: "%.2f", analysis.processingTime)) seconds")
                Text("Videos Found: \(analysis.videos.count)")
                Text("Articles Found: \(analysis.articles.count)")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

/// Section showing found videos
struct VideosSection: View {
    let videos: [Video]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Videos Found (\(videos.count))")
                .font(.title3)
                .padding(.bottom, 8)
            
            if videos.isEmpty {
                Text("No videos found in this analysis")
                    .foregroundColor(.gray)
            } else {
                ForEach(videos, id: \.id) { video in
                    VStack(alignment: .leading) {
                        Text(video.title ?? "Untitled Video")
                            .font(.headline)
                        Text("URL: \(video.url)")
                        Text("Format: \(video.format.rawValue)")
                        if let resolution = video.resolution {
                            Text("Resolution: \(resolution)")
                        }
                        Text("Embed Type: \(video.embedType.rawValue)")
                        Text("Hosting: \(video.hostingSource)")
                        if let duration = video.duration {
                            Text("Duration: \(Int(duration)) seconds")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

/// Section showing found articles
struct ArticlesSection: View {
    let articles: [Article]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Articles with Videos (\(articles.count))")
                .font(.title3)
                .padding(.bottom, 8)
            
            if articles.isEmpty {
                Text("No articles found in this analysis")
                    .foregroundColor(.gray)
            } else {
                ForEach(articles, id: \.id) { article in
                    VStack(alignment: .leading) {
                        Text(article.title)
                            .font(.headline)
                        Text("URL: \(article.url)")
                        if let author = article.author {
                            Text("Author: \(author)")
                        }
                        if let date = article.publicationDate {
                            Text("Published: \(date)")
                        }
                        Text("Videos in Article: \(article.videoPositions.count)")
                        if let excerpt = article.excerpt {
                            Text("Excerpt: \(excerpt)")
                                .lineLimit(3)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

/// Section showing errors
struct ErrorSection: View {
    let errors: [String]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Errors (\(errors.count))")
                .font(.title3)
                .foregroundColor(.red)
                .padding(.bottom, 8)
            
            ForEach(errors, id: \.self) { error in
                Text("- \(error)")
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }
        }
    }
}

// Add necessary import for NSOpenPanel on macOS
#if os(macOS)
import AppKit
#endif