// swift-tools-version:6.2
import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localFrameworkPath = "smbcloud_authFFI.xcframework"
let localFrameworkAbsolutePath = packageRoot.appendingPathComponent(localFrameworkPath).path
let fileManager = FileManager.default
let localFrameworkEntries =
    (try? fileManager.contentsOfDirectory(atPath: localFrameworkAbsolutePath)) ?? []
let hasUsableLocalFramework =
    fileManager.fileExists(atPath: localFrameworkAbsolutePath)
    && localFrameworkEntries.contains(where: { $0.hasPrefix("macos") })

let ffiDependencies: [Target.Dependency] =
    hasUsableLocalFramework ? [.target(name: "smbcloud_authFFI")] : []
let excludedSourceFiles = hasUsableLocalFramework ? [] : ["smbcloud_auth.swift"]
let swiftSettings: [SwiftSetting] =
    hasUsableLocalFramework ? [.define("SMBCLOUD_AUTH_FFI_AVAILABLE")] : []

let targets: [Target] = {
    var targets: [Target] = []

    if hasUsableLocalFramework {
        targets.append(
            .binaryTarget(
                name: "smbcloud_authFFI",
                path: localFrameworkPath
            )
        )
    }

    targets.append(
        .target(
            name: "SmbCloudAuth",
            dependencies: ffiDependencies,
            path: "Sources/SmbCloudAuth",
            exclude: excludedSourceFiles,
            swiftSettings: swiftSettings
        )
    )

    return targets
}()

let package = Package(
    name: "SmbCloudAuth",
    platforms: [
        .iOS(.v16), .macOS(.v14), .tvOS(.v16), .visionOS(.v1),
    ],
    products: [
        .library(name: "SmbCloudAuth", targets: ["SmbCloudAuth"])
    ],
    targets: targets
)
