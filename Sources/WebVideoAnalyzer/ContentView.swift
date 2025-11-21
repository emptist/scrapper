import SwiftUI

/// A basic content view for the GUI version of the app
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Web Video Analyzer")
                .font(.largeTitle)
                .padding()
            
            Text("This application is primarily designed to be used as a command-line tool.")
                .padding()
            
            Text("Usage:\nWebVideoAnalyzer analyze <url>\nWebVideoAnalyzer batch <file>\nWebVideoAnalyzer validate <url>")
                .padding()
                .font(.monospaced(.body)())
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}