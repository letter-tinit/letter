// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Presentation", platforms: [.iOS(.v26)], products: [.library(name: "Presentation", targets: ["Presentation"])], dependencies: [.package(path: "../Domain"), .package(path: "../Utility"), .package(path: "../Styleguide")], targets: [.target(name: "Presentation", dependencies: [.product(name: "Domain", package: "Domain"), .product(name: "Utility", package: "Utility"), .product(name: "Styleguide", package: "Styleguide")], path: "Sources/Presentation")], swiftLanguageModes: [.v5])
