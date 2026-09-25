// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "BeastPanorama", platforms: [.macOS(.v13)], products: [.executable(name: "BeastPanorama", targets: ["BeastPanorama"])], targets: [.executableTarget(name: "BeastPanorama")])
