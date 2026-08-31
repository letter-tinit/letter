// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Utility", platforms: [.iOS(.v26)], products: [.library(name: "Utility", targets: ["Utility"])], targets: [.target(name: "Utility", path: "Sources/Utility")], swiftLanguageModes: [.v5])