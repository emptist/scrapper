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

- **Models**: Video, Article, SiteStructure, and SiteAnalysis data models in VideoAnalyzerCore/Models/
- **Views**: Modern SwiftUI interface with ContentView and modular components for intuitive GUI interaction
- **Services**:
  - **CommandLineHandler**: Manages all command-line operations and argument parsing in WebVideoAnalyzer module
  - **AnalysisService**: Handles all video analysis operations and result processing in WebVideoAnalyzer module
  - **Core Services**: Additional specialized services located in VideoAnalyzerCore/Services/
- **ViewModels**: Dedicated view models in VideoAnalyzerCore/ViewModels/ for business logic and state management
- **Utils**: Utility functions and helpers in VideoAnalyzerCore/Utils/
- **App Entry Point**: VideoFinderApp as the main SwiftUI App entry point with support for both GUI and command-line modes
- **Protocols**: Flexible contracts throughout the codebase for extensibility and testability

## Requirements

- Swift 6.2+
- macOS 14.0+
- Internet connection for web scraping
- SwiftLint for code quality enforcement (recommended)

## Code Quality

This project follows strict code quality guidelines to ensure maintainable and professional code. See [CODE_QUALITY_GUIDELINES.md](CODE_QUALITY_GUIDELINES.md) for detailed standards and enforcement mechanisms.

## Usage

```swift
let analyzer = VideoAnalyzer()
let result = try await analyzer.analyze(url: "https://www.ultrasoundcases.info/appendicitis-6737/")
try analyzer.export(result, format: .json)
try analyzer.export(result, format: .html)
```

## Build and Installation

### Building the GUI Application

To build the macOS application bundle, use the provided build script:

```bash
# Make the build script executable if needed
chmod +x ./build_macos_app.sh

# Run the build script
./build_macos_app.sh
```

This will compile the application and create a `WebVideoAnalyzer.app` bundle in the project directory, ready to be run on macOS.

### Building as a Command-Line Tool

To build the command-line version:

```bash
# Build the project
swift build

# Run the command-line tool using Swift Package Manager
swift run WebVideoAnalyzer <command> [options]
```

After building, you can also run the compiled binary directly (see the Command-Line Usage section below for the binary command format).

## Recent Improvements and Fixes

The following significant improvements and fixes have been implemented in the latest version:

- **SwiftUI Compatibility Fixes**: Updated SwiftUI modifiers and removed deprecated APIs for improved macOS compatibility
- **Main Actor Isolation**: Implemented proper @MainActor annotations and async/await patterns for UI-related operations
- **Closure Capture Safety**: Fixed "escaping closure captures mutating 'self' parameter" errors for more robust code
- **ObservedObject Wrapper Improvements**: Corrected property wrapper usage for better state management
- **Type Safety Enhancements**: Standardized model references (e.g., SiteAnalysis) for improved type consistency
- **File Selection Improvements**: Updated NSOpenPanel implementation to use modern content type filtering
- **Async UI Handling**: Implemented proper Task and await patterns for asynchronous UI operations

## Command-Line Usage

The Web Video Analyzer provides a comprehensive command-line interface for analyzing websites for video content. It supports analyzing individual URLs, processing batch files of URLs, and validating URLs before full analysis.

### Command Format

There are two ways to run the command-line tool:

1. **Using Swift Package Manager** (during development):
   ```bash
   swift run WebVideoAnalyzer <command> [options]
   ```

2. **Using the compiled binary** (after building):
   ```bash
   WebVideoAnalyzer <command> [options]
   ```

### Available Commands

```bash
# Analyze a single URL for video content
WebVideoAnalyzer analyze <url>

# Analyze multiple URLs from a text file (one URL per line)
WebVideoAnalyzer batch <file>

# Validate a URL before performing full analysis
WebVideoAnalyzer validate <url>

# Display help information
WebVideoAnalyzer --help
WebVideoAnalyzer -h
```

### Examples

```bash
# Analyze a single ultrasound case page
WebVideoAnalyzer analyze https://www.ultrasoundcases.info/appendicitis-6737/

# Process multiple URLs from a file
WebVideoAnalyzer batch urls.txt

# Validate a URL before analysis
WebVideoAnalyzer validate https://example.com
```

### Output

Analysis results are saved to the `/tmp/` directory with filenames containing timestamps:
- JSON format: `video_analysis_<timestamp>.json`
- HTML format: `video_analysis_<timestamp>.html`

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
