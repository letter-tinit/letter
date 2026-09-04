// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VieNeuRuntime",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "VieNeuRuntime", targets: ["CVieNeuRuntime"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/csukuangfj/onnxruntime-libs",
            exact: "1.27.1"
        )
    ],
    targets: [
        .binaryTarget(
            name: "SeaG2P",
            path: "Artifacts/SeaG2P.xcframework"
        ),
        .target(
            name: "CVieNeuRuntime",
            dependencies: [
                "SeaG2P",
                .product(
                    name: "onnxruntime-ios",
                    package: "onnxruntime-libs",
                    condition: .when(platforms: [.iOS])
                )
            ],
            path: "Sources/CVieNeuRuntime",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("VIENEU_USE_SEA_G2P"),
                .define(
                    "ACCELERATE_NEW_LAPACK",
                    .when(platforms: [.iOS])
                ),
                .unsafeFlags(["-O3"]),
                .headerSearchPath("Vendor"),
                .headerSearchPath("Vendor/vieneu")
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreML"),
                .linkedFramework("Accelerate"),
                .linkedLibrary("c++")
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
