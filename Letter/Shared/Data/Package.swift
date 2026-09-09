// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v26)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Utility"),
        .package(path: "../../../../LetterEbook"),
        .package(path: "../../../../LetterSpeech")
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Utility", package: "Utility"),
                .product(name: "LetterEbook", package: "LetterEbook"),
                .product(name: "LetterSpeech", package: "LetterSpeech")
            ],
            path: "Sources/Data"
        )
    ],
    swiftLanguageModes: [.v5]
)
