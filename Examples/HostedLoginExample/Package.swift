// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "HostedLoginExample",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "HostedLoginExample",
            dependencies: [
                .product(name: "SmbCloudAuth", package: "smbcloud-auth-swift")
            ],
            path: "Sources/HostedLoginExample"
        )
    ]
)
