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
        .package(url: "git@github.com:Alamofire/Alamofire.git", from: "5.10.0"),
        .package(url: "git@github.com:scinfu/SwiftSoup.git", from: "2.7.0"),
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
                "Alamofire",
                "SwiftSoup"
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
