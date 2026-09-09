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
        .package(url: "git@github.com:letter-tinit/iOSVieNeuRuntime.git", exact: "1.2.1"),
        .package(url: "https://github.com/k2-fsa/sherpa-onnx.git", exact: "1.13.6")
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Utility", package: "Utility"),
                .product(name: "LetterEbook", package: "LetterEbook"),
                .product(name: "VieNeuRuntime", package: "iOSVieNeuRuntime"),
                .product(name: "VieNeuNanoRuntime", package: "iOSVieNeuRuntime"),
                .product(name: "VieNeuNanoModels", package: "iOSVieNeuRuntime"),
                .product(name: "VieNeuTurboModels", package: "iOSVieNeuRuntime"),
                .product(name: "sherpa-onnx", package: "sherpa-onnx")
            ],
            path: "Sources/Data",
            resources: [.copy("Resources/OfflineSpeechModels")]
        )
    ],
    swiftLanguageModes: [.v5]
)
