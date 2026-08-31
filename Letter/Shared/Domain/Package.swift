// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Domain", platforms: [.iOS(.v26)], products: [.library(name: "Domain", targets: ["Domain"])], dependencies: [.package(path: "../Utility")], targets: [.target(name: "Domain", dependencies: [.product(name: "Utility", package: "Utility")], path: "Sources/Domain")], swiftLanguageModes: [.v5])