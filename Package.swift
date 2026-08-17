// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Kamus",
    platforms: [ .macOS(.v12) ],
    products: [
        .executable(name: "Kamus", targets: ["Kamus"])
    ],
    targets: [
        .executableTarget(
            name: "Kamus",
            dependencies: [],
            path: "Sources",
            exclude: ["Kamus/Info.plist", "Kamus/Kamus.entitlements"]
        )
    ]
)
