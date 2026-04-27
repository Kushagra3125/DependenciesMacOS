// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MachoWalkerCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MachoWalkerCore",
            targets: ["MachoWalkerCore"]
        )
    ],
    targets: [
        .target(
            name: "MachoWalkerCore",
            path: "Sources",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("private")
            ]
        )
    ],
    cxxLanguageStandard: .cxx20
)
