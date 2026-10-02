// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "Data",
            targets: ["Data"]
        )
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Utility"),
        .package(url: "git@github.com:letter-tinit/letter-ebook.git", exact: "0.1.0"),
        .package(url: "git@github.com:letter-tinit/letter-speech.git", exact: "0.1.0")
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Utility", package: "Utility"),
                .product(name: "LetterEbook", package: "letter-ebook"),
                .product(name: "LetterSpeech", package: "letter-speech")
            ],
            path: "Sources/Data"
        )
    ],
    swiftLanguageModes: [.v5]
)
