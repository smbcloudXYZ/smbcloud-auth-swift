// swift-tools-version:6.2
import Foundation
import PackageDescription

// ─────────────────────────────────────────────────────────────────────────────
// SmbCloudAuth Swift SDK
//
// Local development: run `make ios` (or another platform target) to build
// SmbCloudAuthFramework.xcframework from the Rust source.  When the local
// framework directory exists, SwiftPM links it directly.
//
// Distribution: consumers add this package via its Git URL.  Without the local
// framework on disk, SwiftPM downloads the pre-built zip from GitHub Releases.
// ─────────────────────────────────────────────────────────────────────────────

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localFrameworkPath = "SmbCloudAuthFramework.xcframework"
let localFrameworkAbsolutePath = packageRoot.appendingPathComponent(localFrameworkPath).path

// Update these two values when cutting a new release.
let releaseFrameworkURL =
    "https://github.com/smbcloudXYZ/smbcloud-auth-swift/releases/download/0.4.1/SmbCloudAuthFramework.xcframework.zip"
let releaseFrameworkChecksum =
    "0000000000000000000000000000000000000000000000000000000000000000"

let smbCloudAuthFrameworkTarget: Target
if FileManager.default.fileExists(atPath: localFrameworkAbsolutePath) {
    smbCloudAuthFrameworkTarget = .binaryTarget(
        name: "SmbCloudAuthFramework",
        path: localFrameworkPath
    )
} else {
    smbCloudAuthFrameworkTarget = .binaryTarget(
        name: "SmbCloudAuthFramework",
        url: releaseFrameworkURL,
        checksum: releaseFrameworkChecksum
    )
}

let package = Package(
    name: "SmbCloudAuth",
    platforms: [
        .iOS(.v16), .macOS(.v14), .tvOS(.v16), .visionOS(.v1),
    ],
    products: [
        .library(name: "SmbCloudAuth", targets: ["SmbCloudAuth"])
    ],
    targets: [
        smbCloudAuthFrameworkTarget,
        .target(
            name: "SmbCloudAuth",
            dependencies: [.target(name: "SmbCloudAuthFramework")],
            path: "Sources/SmbCloudAuth"
        ),
    ]
)
