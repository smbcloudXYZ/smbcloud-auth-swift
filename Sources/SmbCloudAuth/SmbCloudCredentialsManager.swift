import Foundation
import Security

public enum SmbCloudCredentialsManagerError: Error, LocalizedError, Sendable {
    case encodingFailed(String)
    case decodingFailed(String)
    case keychainOperationFailed(status: OSStatus, message: String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let message):
            return message
        case .decodingFailed(let message):
            return message
        case .keychainOperationFailed(_, let message):
            return message
        }
    }
}

public struct SmbCloudCredentialsManager {
    public let service: String
    public let account: String
    public let accessGroup: String?

    public init(
        service: String? = nil,
        account: String = "current",
        accessGroup: String? = nil
    ) {
        self.service = service?.nilIfEmpty ?? Self.defaultServiceName
        self.account = account
        self.accessGroup = accessGroup?.nilIfEmpty
    }

    public func store(_ session: SmbCloudSession) throws {
        let encodedSession: Data
        do {
            encodedSession = try JSONEncoder().encode(session.storedRepresentation())
        } catch {
            throw SmbCloudCredentialsManagerError.encodingFailed(
                "Failed to encode smbCloud session: \(error.localizedDescription)"
            )
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = encodedSession
        addSecureAccessibility(to: &addQuery)

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate = [
                kSecValueData as String: encodedSession
            ]
            let updateStatus = SecItemUpdate(
                baseQuery() as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw keychainError(for: updateStatus)
            }
        default:
            throw keychainError(for: addStatus)
        }
    }

    public func current() throws -> SmbCloudSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw SmbCloudCredentialsManagerError.decodingFailed(
                    "The keychain item did not contain valid session data."
                )
            }

            do {
                return try JSONDecoder().decode(SmbCloudSession.self, from: data)
                    .storedRepresentation()
            } catch {
                throw SmbCloudCredentialsManagerError.decodingFailed(
                    "Failed to decode smbCloud session: \(error.localizedDescription)"
                )
            }
        case errSecItemNotFound:
            return nil
        default:
            throw keychainError(for: status)
        }
    }

    public func currentValidSession(leeway: TimeInterval = 60) throws -> SmbCloudSession? {
        guard let session = try current() else {
            return nil
        }

        return session.isValid(leeway: leeway) ? session : nil
    }

    public func hasValidSession(leeway: TimeInterval = 60) throws -> Bool {
        try currentValidSession(leeway: leeway) != nil
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw keychainError(for: status)
        }
    }
}

extension SmbCloudCredentialsManager {
    fileprivate static var defaultServiceName: String {
        if let bundleIdentifier = Bundle.main.bundleIdentifier?.nilIfEmpty {
            return "\(bundleIdentifier).smbcloud.auth"
        }

        return "xyz.smbcloud.auth"
    }

    fileprivate func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    fileprivate func addSecureAccessibility(to query: inout [String: Any]) {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        #endif
    }

    fileprivate func keychainError(for status: OSStatus) -> SmbCloudCredentialsManagerError {
        let message =
            SecCopyErrorMessageString(status, nil) as String?
            ?? "Keychain operation failed with status \(status)."
        return .keychainOperationFailed(status: status, message: message)
    }
}
