// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WebVideoAnalyzer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WebVideoAnalyzer",
            targets: ["WebVideoAnalyzer"]
        ),
        .library(
            name: "VideoAnalyzerCore",
            targets: ["VideoAnalyzerCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
        .package(url: "https://github.com/SwiftHTMLParser/SwiftHTMLParser.git", from: "0.1.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.12.0"),
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "WebVideoAnalyzer",
            dependencies: [
                "VideoAnalyzerCore",
                "Alamofire"
            ]
        ),
        .target(
            name: "VideoAnalyzerCore",
            dependencies: [
                "Alamofire"
            ]
        ),
        .testTarget(
            name: "VideoAnalyzerCoreTests",
            dependencies: [
                "VideoAnalyzerCore"
            ]
        ),
    ]
)