<h1 align="center">smbCloud Auth for Swift</h1>

<p align="center">
  <strong>Authenticate users on Apple platforms with <a href="https://smbcloud.xyz">smbCloud</a>.</strong>
</p>

<p align="center">
  <a href="https://smbcloud.xyz"><img src="https://img.shields.io/badge/smbcloud.xyz-0969DA?style=flat-square&labelColor=1A1A1A" alt="Website"></a>
  <a href="https://github.com/smbcloudXYZ/smbcloud-auth-swift/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-0969DA?style=flat-square&labelColor=1A1A1A" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/smbcloudXYZ/smbcloud-cli">CLI</a> ·
  <a href="https://www.npmjs.com/package/@smbcloud/sdk-auth">npm</a> ·
  <a href="https://pypi.org/project/smbcloud-sdk-auth/">PyPI</a> ·
  <a href="https://rubygems.org/gems/smbcloud-auth">RubyGems</a> ·
  <a href="https://smbcloud.xyz">Website</a>
</p>

---

## Platforms

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 14.0    |
| tvOS     | 16.0    |
| visionOS | 1.0     |

## Installation

### Xcode

**File → Add Package Dependencies**, then enter:

```
https://github.com/smbcloudXYZ/smbcloud-auth-swift
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/smbcloudXYZ/smbcloud-auth-swift", from: "0.4.1")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SmbCloudAuth", package: "smbcloud-auth-swift")
    ])
]
```

### XcodeGen

```yaml
packages:
  SmbCloudAuth:
    url: https://github.com/smbcloudXYZ/smbcloud-auth-swift
    from: 0.4.1
targets:
  MyApp:
    dependencies:
      - package: SmbCloudAuth
        product: SmbCloudAuth
```

## Quick Start

```swift
import SmbCloudAuth

let auth = SmbCloudAuth(
    environment: .production,
    appId: "your-app-id",
    appSecret: "your-app-secret"
)

// Sign up
let result = try await auth.signup(email: "user@example.com", password: "s3cret")

// Log in
let status = try await auth.login(email: "user@example.com", password: "s3cret")
switch status {
case .ready(let accessToken):
    print("Authenticated: \(accessToken)")
case .incomplete(let errorCode):
    print("Account incomplete: \(errorCode)")
case .notFound:
    print("Account not found")
}

// Get current user
let user = try await auth.me(accessToken: "Bearer ...")
print(user.email)

// Log out
try await auth.logout(accessToken: "Bearer ...")
```

## Apple Sign-In

```swift
// Build the authorization URL
let request = try auth.buildAppleAuthorizationRequest(
    redirectUri: "myapp://auth/callback",
    state: nil // auto-generated if nil
)

// Open request.authorizeUrl in a browser or ASWebAuthenticationSession,
// then parse the callback:
let session = try auth.parseAppleCallbackUrl(
    callbackUrl: callbackUrl,
    expectedState: request.state
)
print(session.accessToken)
```

## OIDC (Authorization Code + PKCE)

```swift
// 1. Build authorization request
let request = try auth.buildOidcAuthorizationRequest(
    oidcClientId: "your-oidc-client-id",
    redirectUri: "myapp://auth/callback"
)
// Open request.authorizeUrl in a browser...

// 2. Parse the callback
let callback = try auth.parseOidcCallbackUrl(callbackUrl: callbackUrl)

// 3. Exchange the code for tokens
let tokens = try await auth.exchangeOidcCode(
    oidcClientId: "your-oidc-client-id",
    redirectUri: "myapp://auth/callback",
    code: callback.code,
    codeVerifier: request.codeVerifier
)
print(tokens.accessToken)

// 4. Fetch user info
let userInfo = try await auth.getOidcUserinfo(
    accessToken: tokens.accessToken,
    tenantId: nil
)
print(userInfo.email ?? "no email")
```

## Error Handling

All methods throw `SmbCloudAuthError` on failure:

```swift
do {
    let status = try await auth.login(email: email, password: password)
} catch let error as SmbCloudAuthError {
    switch error {
    case .api(let errorCode, let message):
        print("API error \(errorCode): \(message)")
    }
}
```

## API Reference

### `SmbCloudAuth`

| Method | Description |
|--------|-------------|
| `login(email:password:)` | Authenticate with email and password |
| `signup(email:password:)` | Create a new account |
| `logout(accessToken:)` | Invalidate an access token |
| `me(accessToken:)` | Fetch the authenticated user profile |
| `removeAccount(accessToken:)` | Permanently delete the authenticated account |
| `buildAppleAuthorizationRequest(redirectUri:state:)` | Build an Apple Sign-In authorization URL |
| `parseAppleCallbackUrl(callbackUrl:expectedState:)` | Parse the Apple Sign-In callback |
| `buildOidcAuthorizationRequest(oidcClientId:redirectUri:)` | Build an OIDC authorization URL with PKCE |
| `parseOidcCallbackUrl(callbackUrl:)` | Parse the OIDC callback for code and state |
| `exchangeOidcCode(oidcClientId:redirectUri:code:codeVerifier:)` | Exchange an authorization code for tokens |
| `getOidcUserinfo(accessToken:tenantId:)` | Fetch OIDC user info |

## Local Development

Clone this repo alongside [smbcloud-cli](https://github.com/smbcloudXYZ/smbcloud-cli):

```
Repositories/
├── smbcloud-cli/
└── smbcloud-auth-swift/
```

Build the XCFramework from the Rust source:

```bash
make ios        # iOS device + simulator
make macos      # macOS (Apple silicon)
make tvos       # tvOS device + simulator
make visionos   # visionOS device + simulator
```

This cross-compiles the Rust `smbcloud-auth-sdk-apple` crate, generates Swift bindings via [UniFFI](https://mozilla.github.io/uniffi-rs/), and packages everything into `SmbCloudAuthFramework.xcframework`.

To point at a different checkout of the Rust repo:

```bash
make ios CLI_REPO=/path/to/smbcloud-cli
```

## How It Works

This package wraps the [smbcloud-auth-sdk](https://github.com/smbcloudXYZ/smbcloud-cli/tree/development/crates/smbcloud-auth-sdk) Rust crate, compiled to a static library for each Apple platform and bridged to Swift via [UniFFI](https://mozilla.github.io/uniffi-rs/) proc-macros. The result is a native Swift API with full async/await support — no Objective-C bridging headers, no C interop in your app code.

## License

Apache 2.0. See [LICENSE](LICENSE).

---

© 2025 [smbCloud](https://smbcloud.xyz).
