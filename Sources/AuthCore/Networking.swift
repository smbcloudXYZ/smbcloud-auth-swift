import Foundation

#if canImport(FoundationNetworking)
    // URLSession lives in FoundationNetworking on non-Apple Swift toolchains.
    import FoundationNetworking
#endif

/// Thin async HTTP layer shared by ``AuthCoreClient`` and ``OIDC``.
///
/// Faithfully reproduces the response handling of the Rust SDK's
/// `smbcloud_network::network::{request, request_login}`: 2xx decodes the
/// payload, anything else is mapped to a ``SmbCloudError``.
struct HTTPTransport: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SmbCloudError(code: .networkError, message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SmbCloudError(code: .networkError)
        }
        return (data, http)
    }

    /// Decodes a 2xx JSON body as `T`; otherwise throws the parsed API error.
    func requestJSON<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, http) = try await send(request)
        guard (200..<300).contains(http.statusCode) else {
            throw Self.apiError(from: data, statusCode: http.statusCode)
        }
        do {
            return try smbCloudDecoder.decode(T.self, from: data)
        } catch {
            throw SmbCloudError(code: .parseError, message: error.localizedDescription)
        }
    }

    /// Succeeds on any 2xx; otherwise throws the parsed API error.
    func requestVoid(_ request: URLRequest) async throws {
        let (data, http) = try await send(request)
        guard (200..<300).contains(http.statusCode) else {
            throw Self.apiError(from: data, statusCode: http.statusCode)
        }
    }

    /// Mirrors `request_login`: maps the sign-in response to an ``AccountStatus``.
    func requestLogin(_ request: URLRequest) async throws -> AccountStatus {
        let (data, http) = try await send(request)

        switch http.statusCode {
        case 200:
            if let auth = http.value(forHTTPHeaderField: "Authorization"), !auth.isEmpty {
                return .ready(accessToken: auth)
            }
            // 200 without a token: parse a status code from the body if present.
            if let parsed = try? smbCloudDecoder.decode(APIErrorBody.self, from: data) {
                switch parsed.errorCode {
                case SmbCloudErrorCode.emailNotVerified.rawValue:
                    return .incomplete(status: .emailUnverified)
                case SmbCloudErrorCode.passwordNotSet.rawValue:
                    return .incomplete(status: .passwordNotSet)
                default:
                    return .notFound
                }
            }
            return .notFound
        case 404:
            return .notFound
        case 422:
            if let parsed = try? smbCloudDecoder.decode(APIErrorBody.self, from: data),
                let code = parsed.errorCode,
                let account = AccountErrorCode(rawValue: code)
            {
                return .incomplete(status: account)
            }
            throw Self.apiError(from: data, statusCode: 422)
        default:
            throw Self.apiError(from: data, statusCode: http.statusCode)
        }
    }

    /// Builds a ``SmbCloudError`` from a non-2xx response body.
    static func apiError(from data: Data, statusCode: Int) -> SmbCloudError {
        if let parsed = try? smbCloudDecoder.decode(APIErrorBody.self, from: data) {
            let code = parsed.errorCode.flatMap(SmbCloudErrorCode.init(rawValue:))
                ?? statusError(statusCode)
            return SmbCloudError(code: code, message: parsed.message ?? code.defaultMessage)
        }
        let code = statusError(statusCode)
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SmbCloudError(code: code, message: (body?.isEmpty == false ? body : nil) ?? code.defaultMessage)
    }

    private static func statusError(_ statusCode: Int) -> SmbCloudErrorCode {
        switch statusCode {
        case 401: return .unauthorized
        case 404: return .emailNotFound
        case 400, 422: return .invalidParams
        default: return .networkError
        }
    }
}

/// `{ "error_code": <int>, "message": "…" }` — the API's error envelope.
private struct APIErrorBody: Decodable {
    let errorCode: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
    }
}

/// Shared decoder: snake_case is handled per-type via explicit `CodingKeys`,
/// and dates use a tolerant ISO-8601 parser (with/without fractional seconds).
let smbCloudDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = SmbCloudDateParser.date(from: raw) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "Unrecognized date format: \(raw)"
        )
    }
    return decoder
}()

enum SmbCloudDateParser {
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }
}
