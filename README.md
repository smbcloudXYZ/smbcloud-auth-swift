<h1 align="center">smbCloud Auth for Swift</h1>

<p align="center">
  <strong>Hosted authentication for Apple apps, built around secure public-client patterns.</strong>
</p>

<p align="center">
  <a href="https://smbcloud.xyz"><img src="https://img.shields.io/badge/smbcloud.xyz-0969DA?style=flat-square&labelColor=1A1A1A" alt="Website"></a>
  <a href="https://github.com/smbcloudXYZ/smbcloud-auth-swift/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-0969DA?style=flat-square&labelColor=1A1A1A" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/smbcloudXYZ/smbcloud-cli">Rust core</a> ·
  <a href="https://www.npmjs.com/package/@smbcloud/sdk-auth">npm</a> ·
  <a href="https://pypi.org/project/smbcloud-sdk-auth/">PyPI</a> ·
  <a href="https://rubygems.org/gems/smbcloud-auth">RubyGems</a> ·
  <a href="https://smbcloud.xyz">Website</a>
</p>

---

## Positioning

`smbcloud-auth-swift` is intended to become the **Apple-platform client SDK** for smbCloud Auth:

- iOS, macOS, tvOS, and visionOS support
- hosted auth via system browser sessions
- OIDC Authorization Code + PKCE
- token exchange and session/profile helpers
- **no client secret embedded in the shipped app**

## Current status

This package is still a **developer preview**, but the v1 public-client MVP surface, docs, tests, packaged example, and release validation workflows now exist.

Today it provides:

- `SmbCloudWebAuth`
- `SmbCloudSession`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient`
- hosted OIDC login with PKCE
- `ASWebAuthenticationSession` orchestration
- callback parsing + code exchange
- local Keychain-backed session persistence
- userinfo lookup
- local session clearing/logout helper

The public `SmbCloudAuth` product is now a stable pure-Swift surface for hosted auth on Apple platforms.
The low-level generated UniFFI layer remains available as an optional local `SmbCloudAuthFFI` product when you build the Rust/XCFramework side during sibling-repo development.

## Security model

### Recommended for public Apple apps

Use:

- hosted auth
- system browser sessions (`ASWebAuthenticationSession`)
- OIDC Authorization Code + PKCE

This is the correct model for:

- App Store apps
- open-source apps
- consumer apps
- partner apps you do not fully control

### Not recommended for shipped public apps

Do **not** embed an smbCloud Auth `app_secret` in:

- the app bundle
- `Info.plist`
- local config copied into the app
- the binary itself

Even if it is not committed to Git, a secret inside a distributed client app is recoverable.

### If you want native email/password forms

Use a backend or BFF/proxy that holds the smbCloud Auth secret on the server.

That pattern is valid when product UX requires native forms, but the server must own the confidential credentials.

## Why this package exists

Apple developers want a native SDK, not just protocol details.

The goal is simple:

1. start auth
2. open hosted login in a system browser session
3. handle callback
4. exchange code
5. store session
6. load profile or log out

## Secure integration patterns

### 1. Hosted auth + PKCE — recommended

Best for:

- public apps
- open-source apps
- App Store distribution

Flow:

1. build OIDC authorization request
2. open hosted auth in `ASWebAuthenticationSession`
3. receive callback URL
4. parse `code` + `state`
5. exchange code with PKCE verifier
6. fetch user info
7. store the resulting session locally

### 2. Backend/BFF proxy — native forms

Best for:

- teams that want a fully native email/password screen
- apps with an existing backend
- managed enterprise deployments

Flow:

1. app shows native login/signup UI
2. app sends credentials to your backend
3. backend talks to smbCloud Auth with confidential credentials
4. backend returns an app-safe session/token response

## Current capabilities

The main public-client API now centers on:

- `SmbCloudWebAuth.login(...)`
- `SmbCloudWebAuth.userInfo(...)`
- `SmbCloudCredentialsManager.store(...)`
- `SmbCloudCredentialsManager.current()`
- `SmbCloudCredentialsManager.currentValidSession(...)`
- `SmbCloudSession`
- `SmbCloudUserInfoClient.userInfo(...)`

That gives Apple apps an end-to-end hosted auth flow without writing their own PKCE, callback, token exchange, and Keychain glue.

## Product direction

The package now exposes an API in this shape:

```/dev/null/swift-example.swift#L1-L23
import SmbCloudAuth

let webAuth = try SmbCloudWebAuth(
    domain: "api.smbcloud.xyz",
    clientId: "your-public-client-id",
    redirectURL: URL(string: "myapp://auth/callback")!
)

let credentials = SmbCloudCredentialsManager()
let session = try await webAuth.login(
    presentationAnchorProvider: {
        window
    },
    credentialsManager: credentials
)

let restored = try credentials.currentValidSession()
let user = try await webAuth.userInfo(session: session)
print(user.email ?? "")
```

And you can fetch profile data without the full web auth wrapper when needed:

```/dev/null/swift-example.swift#L1-L12
let userInfoClient = SmbCloudUserInfoClient(environment: .production)
let user = try await userInfoClient.userInfo(accessToken: session.accessToken)
print(user.sub)
```

## Installation

### Xcode

**File → Add Package Dependencies**, then enter:

```/dev/null/spm.txt#L1-L1
https://github.com/smbcloudXYZ/smbcloud-auth-swift
```

### Swift Package Manager

```/dev/null/package.swift#L1-L8
dependencies: [
    .package(url: "https://github.com/smbcloudXYZ/smbcloud-auth-swift", from: "0.4.1")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SmbCloudAuth", package: "smbcloud-auth-swift")
    ])
]
```

## Platforms

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 14.0    |
| tvOS     | 16.0    |
| visionOS | 1.0     |

Hosted web login currently targets `ASWebAuthenticationSession` platforms: iOS, macOS, and visionOS. The shared session, storage, and userinfo helpers remain usable independently.

## Local development

Clone this repo alongside `smbcloud-cli`:

```/dev/null/tree.txt#L1-L4
Repositories/
├── smbcloud-cli/
└── smbcloud-auth-swift/
```

Build the optional local XCFramework + UniFFI shim from the Rust source:

```/dev/null/bash.txt#L1-L4
make ios
make macos
make tvos
make visionos
```

This cross-compiles the Rust Apple bindings, regenerates `Sources/SmbCloudAuthFFI/smbcloud_auth.swift`, and writes the local XCFramework artifact used by the optional local `SmbCloudAuthFFI` product.

The public `SmbCloudAuth` package can still build without these local Rust artifacts.

## Guides and examples

- [Quick Start — iOS](Docs/QuickStart-iOS.md)
- [Quick Start — macOS](Docs/QuickStart-macOS.md)
- [Migration from proxy/native-form auth](Docs/Migration-From-Proxy-Native-Forms.md)
- [Hosted login example](Examples/HostedLoginExample/README.md)
- [Release process](Docs/Release.md)

You can build the packaged macOS example app locally with:

```/dev/null/bash.txt#L1-L1
swift build --package-path Examples/HostedLoginExample
```

And you can validate generic Apple destination builds locally with:

```/dev/null/bash.txt#L1-L1
make verify-apple-destinations
```

## Roadmap

See [ROADMAP.md](ROADMAP.md).

## Security guidance

See [SECURITY.md](SECURITY.md).

## License

Apache 2.0. See [LICENSE](LICENSE).

---

© 2025 [smbCloud](https://smbcloud.xyz).
