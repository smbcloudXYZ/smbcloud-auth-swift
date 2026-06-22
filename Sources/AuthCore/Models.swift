import Foundation

/// Result of ``AuthCoreClient/login(username:password:)``.
///
/// Mirrors `smbcloud_model::login::AccountStatus`, as mapped from the HTTP
/// response by the Rust SDK's `request_login`.
public enum AccountStatus: Sendable, Equatable {
    /// No account matches the supplied email.
    case notFound
    /// Logged in. `accessToken` is the full `Authorization` header value — it
    /// already includes the `Bearer ` prefix and is passed back verbatim to
    /// ``AuthCoreClient/me(accessToken:)`` and friends.
    case ready(accessToken: String)
    /// The account exists but isn't usable yet (e.g. email unverified).
    case incomplete(status: AccountErrorCode)
}

/// A tenant auth app end user, as returned by `GET /v1/client/me`.
///
/// Mirrors `smbcloud_model::account::User` — the canonical SDK decodes only
/// these fields even though the backend payload carries more.
public struct User: Codable, Sendable, Equatable {
    public let id: Int
    public let email: String
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Result of ``AuthCoreClient/signup(email:password:)``.
///
/// Mirrors `smbcloud_model::signup::SignupResult`.
public struct SignupResult: Codable, Sendable, Equatable {
    public let code: Int?
    public let message: String
    public let data: AccountData?
}

/// Mirrors `smbcloud_model::account::Data`.
public struct AccountData: Codable, Sendable, Equatable {
    public let id: Int
    public let email: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

// MARK: - Apple provider (tenant)

/// A prepared Apple sign-in authorization request (tenant plane).
///
/// Mirrors `apple::AppleAuthorizationRequest`.
public struct AppleAuthorizationRequest: Sendable, Equatable {
    public let authorizeURL: URL
    public let redirectURI: String
    public let state: String
}

/// The tenant auth session parsed from an Apple callback URL.
///
/// Mirrors `apple::AppleAuthSession`.
public struct AppleAuthSession: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let email: String?
    public let name: String?
    public let provider: String
    public let providerAccountId: String
    public let state: String?
}
