import Foundation

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
        guard scopes.isEmpty == false else {
            return nil
        }

        return scopes.joined(separator: " ")
    }

    public var authorizationHeaderValue: String {
        "\(tokenType) \(accessToken)"
    }

    public var isExpired: Bool {
        isExpired(leeway: 0)
    }

    public func isExpired(leeway: TimeInterval = 0) -> Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt <= Date().addingTimeInterval(leeway)
    }

    public func isValid(leeway: TimeInterval = 60) -> Bool {
        isExpired(leeway: leeway) == false
    }
}

extension SmbCloudSession {
    init(tokenResponse: SmbCloudTokenPayload, now: Date = Date()) {
        let expiresAt = tokenResponse.expiresIn.map { now.addingTimeInterval(TimeInterval($0)) }
        self.init(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken?.nilIfEmpty,
            idToken: tokenResponse.idToken?.nilIfEmpty,
            tokenType: tokenResponse.tokenType,
            expiresAt: expiresAt,
            scopes: SmbCloudOpenIDConnectClient.normalizedScopes(from: tokenResponse.scope)
        )
    }

    public func storedRepresentation() -> SmbCloudSession {
        SmbCloudSession(
            accessToken: accessToken,
            refreshToken: refreshToken?.nilIfEmpty,
            idToken: idToken?.nilIfEmpty,
            tokenType: tokenType,
            expiresAt: expiresAt,
            scopes: scopes.smbCloudUniqued()
        )
    }
}

extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension Sequence where Element == String {
    func smbCloudUniqued() -> [String] {
        var seen = Set<String>()

        return compactMap { value in
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedValue.isEmpty == false else {
                return nil
            }

            return seen.insert(trimmedValue).inserted ? trimmedValue : nil
        }
    }
}

extension Sequence where Element == URLQueryItem {
    func firstValue(named name: String) -> String? {
        first(where: { $0.name == name })?.value?.nilIfEmpty
    }
}
