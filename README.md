<h1 align="center">smbCloud Auth for Swift</h1>

<p align="center">
  <strong>Hosted login for Apple apps.</strong>
</p>

<p align="center">
  <a href="https://smbcloud.xyz"><img src="https://img.shields.io/badge/smbcloud.xyz-0969DA?style=flat-square&labelColor=1A1A1A" alt="Website"></a>
  <a href="https://github.com/smbcloudXYZ/smbcloud-auth-swift/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-0969DA?style=flat-square&labelColor=1A1A1A" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/smbcloudXYZ/smbcloud-cli">Rust core</a> ·
  <a href="https://www.npmjs.com/package/@smbcloud/sdk-auth">npm</a> ·
  <a href="https://pypi.org/project/smbcloud-sdk-auth/">PyPI</a> ·
  <a href="https://rubygems.org/gems/smbcloud-auth">RubyGems</a>
</p>

---

`smbcloud-auth-swift` is the Swift package for smbCloud Auth on Apple platforms.

It gives you:

- `SmbCloudWebAuth`
- `SmbCloudSession`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient`

The package is built for public clients:

- Authorization Code + PKCE
- `ASWebAuthenticationSession`
- Keychain-backed local session storage
- no shipped client secret

## Status

Developer preview. The hosted-login MVP is in place and ready to try.

## Installation

### Xcode

Use **File → Add Package Dependencies** and enter:

```text
https://github.com/smbcloudXYZ/smbcloud-auth-swift
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/smbcloudXYZ/smbcloud-auth-swift", from: "1.0.1")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SmbCloudAuth", package: "smbcloud-auth-swift")
    ])
]
```

## Quick example

```swift
import SmbCloudAuth

let webAuth = try SmbCloudWebAuth(
    domain: "api.smbcloud.xyz",
    clientId: "your-public-client-id",
    redirectURL: URL(string: "myapp://auth/callback")!
)

let credentials = SmbCloudCredentialsManager(
    service: "com.example.myapp.smbcloud-auth"
)

let session = try await webAuth.login(
    presentationAnchorProvider: {
        window
    },
    credentialsManager: credentials
)

let user = try await webAuth.userInfo(session: session)
print(user.email ?? "Signed in")
```

## Platforms

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 14.0    |
| tvOS     | 16.0    |
| visionOS | 1.0     |

Hosted web login currently runs on iOS, macOS, and visionOS. The session, storage, and user info helpers can still be used on other supported Apple platforms.

## Security note

- Use a public client ID.
- Do not embed an smbCloud Auth `app_secret` in the app.
- Use system browser auth, not embedded webviews.
- If you need native email/password forms, keep confidential credentials on your backend or BFF.
- `logout()` currently clears local credentials only.

## Guides

- [Quick Start — iOS](Docs/QuickStart-iOS.md)
- [Quick Start — macOS](Docs/QuickStart-macOS.md)
- [Migration from proxy/native-form auth](Docs/Migration-From-Proxy-Native-Forms.md)
- [Hosted login example](Examples/HostedLoginExample/README.md)
- [Release process](Docs/Release.md)

## Local development

Clone this repo alongside `smbcloud-cli`:

```text
Repositories/
├── smbcloud-cli/
└── smbcloud-auth-swift/
```

Build the optional local XCFramework and UniFFI shim from the Rust source:

```bash
make ios
make macos
make tvos
make visionos
```

The public `SmbCloudAuth` product builds without local Rust artifacts. `SmbCloudAuthFFI` is there for sibling-repo development when you need the local bridge.

## License

Apache 2.0. See [LICENSE](LICENSE).

---

© 2025 [smbCloud](https://smbcloud.xyz).
