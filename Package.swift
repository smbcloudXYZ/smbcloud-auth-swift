// swift-tools-version:6.1
import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fileManager = FileManager.default

let localFrameworkPath = "smbcloud_authFFI.xcframework"
let localFrameworkAbsolutePath = packageRoot.appendingPathComponent(localFrameworkPath).path
let localFfiMarkerPath = packageRoot.appendingPathComponent(".local/use-local-ffi").path
let ffiSwiftShimPath = packageRoot.appendingPathComponent(
    "Sources/SmbCloudAuthFFI/smbcloud_auth.swift"
).path

let shouldEnableLocalFfi =
    fileManager.fileExists(atPath: localFfiMarkerPath)
    && fileManager.fileExists(atPath: localFrameworkAbsolutePath)
    && fileManager.fileExists(atPath: ffiSwiftShimPath)

let targets: [Target] = {
    var targets: [Target] = [
        .target(
            name: "SmbCloudAuth",
            path: "Sources/SmbCloudAuth"
        )
    ]

    if shouldEnableLocalFfi {
        targets.append(
            .binaryTarget(
                name: "smbcloud_authFFI",
                path: localFrameworkPath
            )
        )

        targets.append(
            .target(
                name: "SmbCloudAuthFFI",
                dependencies: [.target(name: "smbcloud_authFFI")],
                path: "Sources/SmbCloudAuthFFI"
            )
        )
    }

    targets.append(
        .testTarget(
            name: "SmbCloudAuthTests",
            dependencies: ["SmbCloudAuth"],
            path: "Tests/SmbCloudAuthTests"
        )
    )

    return targets
}()

let products: [Product] = {
    var products: [Product] = [
        .library(name: "SmbCloudAuth", targets: ["SmbCloudAuth"])
    ]

    if shouldEnableLocalFfi {
        products.append(
            .library(name: "SmbCloudAuthFFI", targets: ["SmbCloudAuthFFI"])
        )
    }

    return products
}()

let package = Package(
    name: "SmbCloudAuth",
    platforms: [
        .iOS(.v16), .macOS(.v14), .tvOS(.v16), .visionOS(.v1),
    ],
    products: products,
    targets: targets
)
