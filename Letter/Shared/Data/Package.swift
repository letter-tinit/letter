// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v26)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Utility"),
        .package(path: "../VieNeuRuntime"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
        .package(url: "https://github.com/k2-fsa/sherpa-onnx.git", exact: "1.13.6")
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Utility", package: "Utility"),
                .product(name: "VieNeuRuntime", package: "VieNeuRuntime"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "sherpa-onnx", package: "sherpa-onnx")
            ],
            path: "Sources/Data",
            resources: [.copy("Resources/OfflineSpeechModels")]
        )
    ],
    swiftLanguageModes: [.v5]
)
