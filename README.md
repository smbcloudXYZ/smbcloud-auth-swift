<h1 align="center">smbCloud Auth for Swift</h1>

<p align="center">
  <strong>Native Swift SDK for smbCloud Auth — server-side and Apple apps.</strong>
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

`smbcloud-auth-swift` is the Swift SDK for smbCloud Auth. It authenticates a
tenant auth app's end users (**`AuthUser`**) against the smbCloud tenant client
API (`/v1/client/*`).

It ships **two products**:

| Product | Platforms | What it's for |
|---------|-----------|---------------|
| **`AuthCore`** | Apple · Linux · Windows · Android | Headless, UI-free auth engine (use server-side too) |
| **`SmbCloudAuth`** | Apple only | Hosted login UI + Keychain on top of `AuthCore` |

`AuthCore` gives you:

- `AuthCoreClient` — the tenant credential client: `login`, `signup`, `me`,
  `logout`, `remove`, plus the Apple provider helpers. Uses confidential
  `ClientCredentials` (`appId` + `appSecret`).
- `OIDC` — the public-client OIDC Authorization Code + PKCE flow
  (`buildAuthorizationRequest`, `parseCallbackURL`, `exchangeCode`, `getUserInfo`).
- `SmbCloudSession` and `SmbCloudCredentialsStore` (+ `SmbCloudInMemoryCredentialsStore`).
- `SmbCloudError` / `SmbCloudErrorCode`, `AccountStatus`, `User`, `SignupResult`.

`SmbCloudAuth` adds the Apple UI/platform layer and re-exports `AuthCore`:

- `SmbCloudWebAuth` — `ASWebAuthenticationSession` hosted login over the OIDC flow
- `SmbCloudCredentialsManager` — Keychain-backed `SmbCloudCredentialsStore`

### Confidential vs public clients

- **Confidential** (`AuthCoreClient`): `appId` + `appSecret`. Use it where the
  secret stays private — a backend / BFF, the CLI, server-side Swift. The
  email/password `login`/`signup` calls require it.
- **Public** (`SmbCloudWebAuth` / `OIDC`): no secret. This is the path for
  native and browser apps. **Never ship `appSecret` in a distributed app.**

### Relationship to the Rust SDK

The contract authority is the Rust crate
[`smbcloud-cli/crates/smbcloud-auth-sdk`](https://github.com/smbcloudXYZ/smbcloud-cli),
which the `-py` and `-wasm` bindings wrap. `AuthCore` is a faithful **native**
Swift port of it (no Rust/UniFFI dependency, so it builds with plain
`swift build` everywhere, including Linux servers), pinned to the crate by a
shared conformance suite. Apple consumers use this package directly — there is
no UniFFI Apple binding. See
[`Docs/AuthCore-SDK-Surface.md`](Docs/AuthCore-SDK-Surface.md).

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/smbcloudXYZ/smbcloud-auth-swift", from: "1.0.0")
],
targets: [
    // Apple app: the UI layer.
    .target(name: "MyApp", dependencies: [
        .product(name: "SmbCloudAuth", package: "smbcloud-auth-swift")
    ]),
    // Server / cross-platform: the headless engine.
    .target(name: "MyServer", dependencies: [
        .product(name: "AuthCore", package: "smbcloud-auth-swift")
    ])
]
```

## Quick example (Apple, public client)

```swift
import SmbCloudAuth

let webAuth = SmbCloudWebAuth(
    environment: .production,
    oidcClientId: "your-oidc-client-id",
    redirectURL: URL(string: "myapp://auth/callback")!
)

let credentials = SmbCloudCredentialsManager(
    service: "com.example.myapp.smbcloud-auth"
)

let session = try await webAuth.login(
    presentationAnchorProvider: { window },
    credentialsManager: credentials
)

let user = try await webAuth.userInfo(session: session)
print(user.email ?? "Signed in")
```

## Quick example (server-side / headless, confidential client)

On a backend (e.g. a Vapor service) you hold the `appSecret` and can use the
tenant credential flow directly:

```swift
import AuthCore

let client = AuthCoreClient(
    environment: .production,
    credentials: ClientCredentials(appId: appId, appSecret: appSecret)
)

switch try await client.login(username: email, password: password) {
case .ready(let accessToken):
    let user = try await client.me(accessToken: accessToken)   // GET /v1/client/me
    print(user.email)
case .incomplete(let status):
    print("Account not ready: \(status)")      // e.g. .emailUnverified
case .notFound:
    print("No such account")
}
```

`AuthCoreClient.login` returns the access token inside `.ready(accessToken:)` as
the full `Authorization` header value (it already includes `Bearer `); pass it
back to `me`/`logout`/`remove` verbatim.

## Platforms

`SmbCloudAuth` (hosted-login UI + Keychain):

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 14.0    |
| tvOS     | 16.0    |
| visionOS | 1.0     |

`SmbCloudWebAuth` runs on iOS, macOS, and visionOS. `AuthCore` additionally
builds on **Linux, Windows, and Android**, with no dependency on UIKit/AppKit,
`AuthenticationServices`, or the Keychain (it uses
[swift-crypto](https://github.com/apple/swift-crypto) for OIDC PKCE off Apple
platforms). Bring your own `SmbCloudCredentialsStore` (or use
`SmbCloudInMemoryCredentialsStore`) for persistence.

## Security notes

- Native and browser apps are **public clients**: use `SmbCloudWebAuth` / `OIDC`,
  not a shipped `appSecret`.
- Keep `appSecret` and email/password (`AuthCoreClient`) on a backend / BFF.
- Use system browser auth, not embedded webviews.
- `logout()` clears local credentials.

## License

Apache 2.0. See [LICENSE](LICENSE).

---

© 2025 [smbCloud](https://smbcloud.xyz).
