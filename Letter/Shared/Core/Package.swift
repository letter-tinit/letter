// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Core", platforms: [.iOS(.v26)], products: [.library(name: "Core", targets: ["Core"])], dependencies: [.package(path: "../Utility")], targets: [.target(name: "Core", dependencies: [.product(name: "Utility", package: "Utility")], path: "Sources/Core")], swiftLanguageModes: [.v5])