// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "GmailBlockApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GmailBlockApp", targets: ["GmailBlockApp"])
    ],
    targets: [
        .executableTarget(
            name: "GmailBlockApp",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
