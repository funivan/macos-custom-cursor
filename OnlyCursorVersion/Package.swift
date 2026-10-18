// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CustomCursorDemo",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CustomCursorDemo", targets: ["CustomCursorDemo"])
    ],
    targets: [
        .executableTarget(
            name: "CustomCursorDemo",
            path: ".",
            sources: ["CustomCursorDemoApp.swift", "ContentView.swift"]
        )
    ]
)
