import Foundation

/// A persisted credential — the access token plus optional refresh/id tokens
/// and expiry. Produced by the OIDC token exchange (and storable from a tenant
/// login), and what ``SmbCloudCredentialsStore`` persists.
public struct SmbCloudSession: Codable, Equatable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?
    public let tokenType: String
    public let expiresAt: Date?
    public let scopes: [String]

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        scopes: [String] = []
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.scopes = scopes
    }

    public var scope: String? {
        scopes.isEmpty ? nil : scopes.joined(separator: " ")
    }

    public var authorizationHeaderValue: String {
        "\(tokenType) \(accessToken)"
    }

    public var isExpired: Bool {
        isExpired(leeway: 0)
    }

    public func isExpired(leeway: TimeInterval = 0) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date().addingTimeInterval(leeway)
    }

    public func isValid(leeway: TimeInterval = 60) -> Bool {
        isExpired(leeway: leeway) == false
    }
}

extension SmbCloudSession {
    /// Builds a session from an OIDC token exchange response.
    public init(tokenResponse: OIDC.TokenResponse, now: Date = Date()) {
        let expiresAt = tokenResponse.expiresIn.map { now.addingTimeInterval(TimeInterval($0)) }
        let scopes =
            tokenResponse.scope?
            .split(separator: " ")
            .map(String.init)
            .smbCloudUniqued() ?? []
        self.init(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken?.smbCloudNilIfEmpty,
            idToken: tokenResponse.idToken?.smbCloudNilIfEmpty,
            tokenType: tokenResponse.tokenType,
            expiresAt: expiresAt,
            scopes: scopes
        )
    }

    /// A normalized copy (trimmed/deduped scopes, empty tokens dropped).
    public func storedRepresentation() -> SmbCloudSession {
        SmbCloudSession(
            accessToken: accessToken,
            refreshToken: refreshToken?.smbCloudNilIfEmpty,
            idToken: idToken?.smbCloudNilIfEmpty,
            tokenType: tokenType,
            expiresAt: expiresAt,
            scopes: scopes.smbCloudUniqued()
        )
    }
}

extension String {
    var smbCloudNilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension Sequence where Element == String {
    func smbCloudUniqued() -> [String] {
        var seen = Set<String>()
        return compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return seen.insert(trimmed).inserted ? trimmed : nil
        }
    }
}
