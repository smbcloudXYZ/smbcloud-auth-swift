# AuthCore target surface — pinned to `smbcloud-auth-sdk`

**Status:** design spec for correcting `AuthCore`.

## Principle

`AuthCore` is a **faithful Swift port of the canonical client SDK core,
`smbcloud-cli/crates/smbcloud-auth-sdk`** — the same crate wrapped by the
`-apple`, `-py`, and `-wasm` bindings. The Rust crate is the **contract
authority**; `smbcloud-model` is the **DTO/type authority**; the Rails
`smbcloud-api` is the ultimate wire truth. AuthCore implements the contract
natively in Swift (no Rust/UniFFI dependency, so it builds cleanly on Linux
server-side and on Apple) and is held in lockstep by a **shared conformance
suite** run against the same fixtures/contract as the other bindings.

> The previously shipped `AuthCore` (`SmbCloudAuthClient` doing `oauth/authorize`
> PKCE) corresponds to *only* the `oidc.rs` module and was mislabeled as the
> whole SDK — it omitted the primary tenant credential flow. This spec restores
> the full surface.

Module map (`smbcloud-auth-sdk/src/*` → AuthCore):

| Rust module            | AuthCore surface                                   |
|------------------------|----------------------------------------------------|
| `client_credentials.rs`| `ClientCredentials`, base-URL builder              |
| `login.rs`             | `AuthCoreClient.login`                             |
| `signup.rs`            | `AuthCoreClient.signup`                            |
| `me.rs`                | `AuthCoreClient.me`                                |
| `logout.rs`            | `AuthCoreClient.logout`                            |
| `remove.rs`            | `AuthCoreClient.remove`                            |
| `apple.rs`             | `AuthCoreClient.buildAppleAuthorizationRequest` / `parseAppleCallbackURL` |
| `oidc.rs`              | `OIDC.*` (public-client PKCE)                       |

## Shared types

```swift
/// Mirrors smbcloud_network::environment::Environment.
public enum SmbCloudEnvironment: Sendable {
    case dev          // http  · localhost:8088
    case production   // https · api.smbcloud.xyz

    public var apiProtocol: String { self == .dev ? "http" : "https" }
    public var apiHost: String { self == .dev ? "localhost:8088" : "api.smbcloud.xyz" }
}

/// Mirrors client_credentials::ClientCredentials. Sent as the `client_id` and
/// `client_secret` QUERY params on every /v1/client/* request.
public struct ClientCredentials: Sendable {
    public let appId: String
    public let appSecret: String
    public init(appId: String, appSecret: String)
}

/// Mirrors smbcloud_model::error_codes::{ErrorResponse, ErrorCode}.
public struct SmbCloudError: Error, Sendable {
    public let code: SmbCloudErrorCode
    public let message: String
}

public enum SmbCloudErrorCode: Int, Sendable {
    case unknown = 0, parseError = 1, networkError = 2, inputError = 3,
         missingConfig = 4, cancel = 5
    case unauthorized = 100, invalidParams = 101
    case emailNotFound = 1000, emailNotVerified = 1001, emailConfirmationFailed = 1002,
         passwordNotSet = 1003, gitHubEmailNotConnected = 1004, emailAlreadyExist = 1005,
         invalidPassword = 1006
    case projectNotFound = 2000, unsupportedRunner = 2001
}
```

## Tenant credential flow (primary)

```swift
public struct AuthCoreClient: Sendable {
    public init(environment: SmbCloudEnvironment, credentials: ClientCredentials)

    // login.rs → POST /v1/client/users/sign_in  (body {user:{email,password}})
    public func login(username: String, password: String) async throws -> AccountStatus

    // signup.rs → POST /v1/client/users          (body {user:{email,password}})
    public func signup(email: String, password: String) async throws -> SignupResult

    // me.rs     → GET  /v1/client/me
    public func me(accessToken: String) async throws -> User

    // logout.rs → DELETE /v1/client/users/sign_out
    public func logout(accessToken: String) async throws

    // remove.rs → DELETE /v1/client/me
    public func remove(accessToken: String) async throws

    // Account recovery — ahead of smbcloud-auth-sdk (backend has these; the
    // canonical crate doesn't wrap them yet). Upstream for parity. Each returns
    // the server's user-facing message.
    public func requestPasswordReset(email: String) async throws -> String          // POST users/reset_password
    public func completePasswordReset(token:password:passwordConfirmation:) async throws -> String  // POST users/reset_password/complete
    public func resendConfirmation(email: String) async throws -> String            // POST users/resend_confirmation
}

/// login.rs result, mapped by network::request_login.
public enum AccountStatus: Sendable {
    case notFound
    case ready(accessToken: String)          // full Authorization header value (includes "Bearer ")
    case incomplete(status: AccountErrorCode)
}

/// Mirrors smbcloud_model::account::ErrorCode (distinct from SmbCloudErrorCode).
public enum AccountErrorCode: Int, Sendable {
    case emailNotFound = 1000, emailUnverified = 1001, emailConfirmationFailed = 1002,
         passwordNotSet = 1003, githubNotLinked = 1004, emailAlreadyExist = 1005,
         invalidPassword = 1006, hostedMailAccountUnverified = 1007
}

/// me.rs returns smbcloud_model::account::User (the SDK decodes only these).
public struct User: Codable, Sendable {
    public let id: Int
    public let email: String
    public let createdAt: Date
    public let updatedAt: Date
}

/// signup.rs returns smbcloud_model::signup::SignupResult.
public struct SignupResult: Codable, Sendable {
    public let code: Int?
    public let message: String
    public let data: AccountData?
}

public struct AccountData: Codable, Sendable {   // account::Data
    public let id: Int
    public let email: String
    public let createdAt: String
}
```

### `login` → `AccountStatus` mapping (from `network::request_login`)

| HTTP                              | Result |
|-----------------------------------|--------|
| `200` + `Authorization` header    | `.ready(accessToken: <header value>)` |
| `200`, no header, body `EmailNotVerified` | `.incomplete(.emailUnverified)` |
| `200`, no header, body `PasswordNotSet`   | `.incomplete(.passwordNotSet)` |
| `404`                             | `.notFound` |
| `422`                             | parse `SmbAuthorization` → `.incomplete(error_code)`, else throw `SmbCloudError(.networkError, message)` |
| transport failure                 | throw `SmbCloudError(.networkError, …)` |

## Apple provider flow (tenant)

```swift
extension AuthCoreClient {
    // apple.rs → builds v1/client/oauth/apple/authorize URL (creds in query)
    public func buildAppleAuthorizationRequest(
        redirectURI: String, state: String? = nil
    ) throws -> AppleAuthorizationRequest

    public func parseAppleCallbackURL(
        _ callbackURL: String, expectedState: String? = nil
    ) throws -> AppleAuthSession
}

public struct AppleAuthorizationRequest: Sendable {
    public let authorizeURL: String
    public let redirectURI: String
    public let state: String
}

public struct AppleAuthSession: Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let email: String?
    public let name: String?
    public let provider: String            // defaults "apple"
    public let providerAccountId: String
    public let state: String?
}
```

## OIDC public-client flow (`oidc.rs`)

Public client: uses `oidcClientId` only — **no `app_secret`** — against the
issuer endpoints `oauth/authorize|token|userinfo`. PKCE: `code_verifier` = two
concatenated UUID-simple strings; `code_challenge` = base64url-no-pad(SHA256);
`code_challenge_method=S256`; `scope="openid profile email"`.

```swift
public enum OIDC {
    public static func buildAuthorizationRequest(
        environment: SmbCloudEnvironment, oidcClientId: String, redirectURI: String
    ) throws -> AuthorizationRequest

    public static func parseCallbackURL(_ callbackURL: String) throws -> CallbackPayload

    public static func exchangeCode(
        environment: SmbCloudEnvironment, oidcClientId: String,
        redirectURI: String, code: String, codeVerifier: String
    ) async throws -> TokenResponse

    public static func getUserInfo(
        environment: SmbCloudEnvironment, accessToken: String, tenantId: String? = nil
    ) async throws -> UserInfo
}

public struct AuthorizationRequest: Sendable {
    public let authorizeURL: String
    public let redirectURI: String
    public let state: String
    public let codeVerifier: String
}
public struct CallbackPayload: Sendable { public let code: String; public let state: String }
public struct TokenResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int?
    public let refreshToken: String?
    public let scope: String?
    public let idToken: String?
}
public struct UserInfo: Codable, Sendable {
    public let sub: String
    public let email: String?
    public let emailVerified: Bool?
    public let tenantId: UInt64?
    public let tenantSlug: String?
}
```

## Transport notes (match the Rust crate exactly)

- **Credentials are QUERY params** named `client_id` / `client_secret` on every
  `/v1/client/*` URL (built by `base_url_builder`), even for POST/DELETE.
- `login` / `signup` send header `User-agent: <app_id>` and a JSON body.
- `me` sends `Authorization: <accessToken>` (the value is passed **as-is** — it
  already includes the `Bearer ` prefix because `.ready` captured the full
  header), plus `Accept: application/json` and
  `Content-Type: application/x-www-form-urlencoded`.
- `logout` is bespoke: `200` → success, anything else → `SmbCloudError(.unauthorized)`.
- `remove` decodes an empty body (`request::<()>`).
- Use the host HTTP stack (`URLSession` on Apple, `URLSession`/async-http-client
  on Linux). No embedded runtime.

## Layering & client confidentiality

- `AuthCore` (this surface) is headless and builds on Linux + Apple. The Vapor
  `api-server` depends on it directly and is the **only** place that holds
  `app_secret` (confidential client).
- `SmbCloudAuth` (Apple-only) keeps the UI/Keychain layer (ASWebAuthenticationSession
  for the OIDC/Apple flows) and re-exports `AuthCore`.
- **Never ship `app_secret` in a distributed client** (native app / browser).
  Public clients use the OIDC/Apple public flows or route through a BFF
  (SwiftStore's `api-server`).

## Conformance

Pin AuthCore to the crate with shared contract tests: golden request fixtures
(method, path, query, headers, body) and response→type fixtures covering the
`AccountStatus` mapping and the error model, run in CI exactly as the other
bindings are. Drift fails the build.
