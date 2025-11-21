# Web Video Analyzer

A comprehensive Swift tool for analyzing web pages to identify and extract video content, including embedded videos, video metadata, and article associations.

## Features

- **Video Detection**: Identifies videos using HTML5 video tags, iframe embeds, and JavaScript-rendered content
- **Article Analysis**: Detects articles containing embedded videos with metadata extraction
- **Comprehensive Output**: Generates structured lists of video URLs with formats, resolutions, and hosting sources
- **Multiple Export Formats**: JSON and HTML export options
- **Error Handling**: Robust error handling for dynamic and protected content
- **Duplicate Detection**: Prevents duplicate video entries
- **Swift 6.2**: Built with latest Swift features and testing frameworks

## Architecture

This project follows MVVM (Model-View-ViewModel) architecture combined with Protocol-Oriented Programming (POP) principles and good separation of concerns:

- **Models**: Video, Article, SiteStructure data models in VideoAnalyzerCore
- **Views**: Basic UI with ContentView for minimal GUI interaction
- **Services**:
  - **CommandLineHandler**: Manages all command-line operations and argument parsing
  - **AnalysisService**: Handles all video analysis operations and result processing
- **App Entry Point**: ScrapperApp as the main SwiftUI App entry point
- **Protocols**: Flexible contracts for different implementations

## Requirements

- Swift 6.2+
- macOS 14.0+
- Internet connection for web scraping

## Usage

```swift
let analyzer = VideoAnalyzer()
let result = try await analyzer.analyze(url: "https://www.ultrasoundcases.info/appendicitis-6737/")
try analyzer.export(result, format: .json)
try analyzer.export(result, format: .html)
```

## Testing

The project uses Swift's latest testing features for comprehensive unit and integration tests with a focus on resilience:

### Key Testing Principles
- **Resilient Assertions**: Uses range validations and content presence checks instead of brittle exact matches
- **Input Immutability**: Ensures test inputs remain unchanged during processing
- **Comprehensive Coverage**: Tests cover video detection, format handling, YouTube embeds, and medical content detection
- **Error Management**: Verifies robust error handling and logging
- **Output Validation**: Confirms proper export functionality in both JSON and HTML formats

```swift
@testable import VideoAnalyzerCore
import Testing

struct VideoAnalyzerTests {
    @Test func videoDetection() async throws {
        // Test using resilient assertions that verify core functionality
        // without being overly sensitive to implementation details
    }
}
```

### Running Tests
To run the tests, use the Swift package manager:
```bash
swift test
```

For running specific tests:
```bash
swift test --filter VideoAnalyzerEngineTests
```