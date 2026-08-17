// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TDKDictionary",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "TDKDictionary", targets: ["TDKDictionary"])
    ],
    targets: [
        .executableTarget(
            name: "TDKDictionary",
            dependencies: [],
            path: "Sources",
            exclude: ["TDKDictionary/Info.plist", "TDKDictionary/TDKDictionary.entitlements"]
        )
    ]
)
