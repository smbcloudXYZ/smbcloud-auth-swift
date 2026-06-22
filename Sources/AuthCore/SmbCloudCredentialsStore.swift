import Foundation

/// Abstraction over session persistence.
///
/// `AuthCore` is platform-agnostic, so it does not assume a Keychain (or any
/// particular storage backend). Provide a conforming type to persist sessions
/// however is appropriate for your platform:
///
/// - On Apple platforms, `SmbCloudCredentialsManager` (from the `SmbCloudAuth`
///   product) stores sessions in the Keychain.
/// - For tests, scripts, or servers, use ``SmbCloudInMemoryCredentialsStore``.
/// - On Linux / Windows / Android, implement this protocol on top of your
///   platform's secure storage (e.g. libsecret, DPAPI, Android Keystore).
public protocol SmbCloudCredentialsStore: Sendable {
    /// Persists (or replaces) the stored session.
    func store(_ session: SmbCloudSession) throws
    /// Returns the stored session, if any.
    func current() throws -> SmbCloudSession?
    /// Removes any stored session.
    func clear() throws
}

extension SmbCloudCredentialsStore {
    /// Returns the stored session only if it is still valid within `leeway` seconds.
    public func currentValidSession(leeway: TimeInterval = 60) throws -> SmbCloudSession? {
        guard let session = try current() else {
            return nil
        }

        return session.isValid(leeway: leeway) ? session : nil
    }

    /// Whether a valid (non-expired) session is currently stored.
    public func hasValidSession(leeway: TimeInterval = 60) throws -> Bool {
        try currentValidSession(leeway: leeway) != nil
    }
}

/// A thread-safe, in-memory ``SmbCloudCredentialsStore``.
///
/// Sessions live only for the lifetime of the process. This is handy for unit
/// tests, command-line tools, and server-side flows, and it works identically
/// on every platform AuthCore supports.
public final class SmbCloudInMemoryCredentialsStore: SmbCloudCredentialsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: SmbCloudSession?

    public init(session: SmbCloudSession? = nil) {
        self.session = session?.storedRepresentation()
    }

    public func store(_ session: SmbCloudSession) throws {
        lock.lock()
        defer { lock.unlock() }
        self.session = session.storedRepresentation()
    }

    public func current() throws -> SmbCloudSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        session = nil
    }
}
