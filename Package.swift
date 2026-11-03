// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkTheRoughcut",
    platforms: [.macOS(.v13)],
    targets: [
        // timecode, markers, Avid import/export – no UI, fully tested
        .target(name: "MarkerCore", path: "Sources/MarkerCore"),
        .executableTarget(name: "MarkTheRoughcut", dependencies: ["MarkerCore"], path: "Sources/MarkTheRoughcut"),
        .testTarget(name: "MarkerCoreTests", dependencies: ["MarkerCore"], path: "Tests/MarkerCoreTests"),
        .testTarget(name: "AppTests", dependencies: ["MarkTheRoughcut"], path: "Tests/AppTests"),
    ]
)
