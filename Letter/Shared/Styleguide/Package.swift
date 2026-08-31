// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Styleguide", platforms: [.iOS(.v26)], products: [.library(name: "Styleguide", targets: ["Styleguide"])], dependencies: [.package(path: "../Domain"), .package(path: "../Utility")], targets: [.target(name: "Styleguide", dependencies: [.product(name: "Domain", package: "Domain"), .product(name: "Utility", package: "Utility")], path: "Sources/Styleguide")], swiftLanguageModes: [.v5])
