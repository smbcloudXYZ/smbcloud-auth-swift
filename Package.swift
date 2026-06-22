// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SmbCloudAuth",
    platforms: [
        .iOS(.v16), .macOS(.v14), .tvOS(.v16), .visionOS(.v1),
    ],
    products: [
        .library(name: "AuthCore", targets: ["AuthCore"]),
        .library(name: "SmbCloudAuth", targets: ["SmbCloudAuth"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            "3.0.0" ..< "5.0.0"
        )
    ],
    targets: [
        // Cross-platform core. Builds on Apple platforms, Linux, Windows, and
        // Android. No UIKit/AppKit, AuthenticationServices, or Keychain.
        //
        // A faithful native Swift port of the canonical client SDK,
        // `smbcloud-cli/crates/smbcloud-auth-sdk` (the crate the `-py`/`-wasm`
        // bindings wrap). The Rust crate is the contract authority; AuthCore is
        // pinned to it by a shared conformance suite — there is intentionally no
        // Rust/UniFFI dependency, so this builds with plain `swift build`
        // everywhere, including server-side.
        .target(
            name: "AuthCore",
            dependencies: [
                // CryptoKit is used on Apple platforms; swift-crypto provides the
                // same SHA256 API everywhere else (used for OIDC PKCE).
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux, .windows, .android])
                )
            ],
            path: "Sources/AuthCore"
        ),
        // Apple-platform UI layer: ASWebAuthenticationSession hosted login and
        // the Keychain-backed credentials manager. Re-exports AuthCore.
        .target(
            name: "SmbCloudAuth",
            dependencies: ["AuthCore"],
            path: "Sources/SmbCloudAuth"
        ),
        .testTarget(
            name: "AuthCoreTests",
            dependencies: ["AuthCore"],
            path: "Tests/AuthCoreTests"
        ),
        .testTarget(
            name: "SmbCloudAuthTests",
            dependencies: ["SmbCloudAuth"],
            path: "Tests/SmbCloudAuthTests"
        ),
    ]
)
