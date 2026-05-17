import SmbCloudAuth
import SwiftUI

@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var session: SmbCloudSession?
    @Published private(set) var userEmail: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let webAuth: SmbCloudWebAuth?
    private let credentialsManager = SmbCloudCredentialsManager(
        service: "com.example.hosted-login-example.smbcloud-auth"
    )

    init() {
        do {
            self.webAuth = try SmbCloudWebAuth(
                domain: "api.smbcloud.xyz",
                clientId: "YOUR_PUBLIC_CLIENT_ID",
                redirectURL: URL(string: "hostedloginexample://auth/callback")!
            )
        } catch {
            self.webAuth = nil
            self.errorMessage = error.localizedDescription
        }
    }

    func restoreSession() {
        do {
            session = try credentialsManager.currentValidSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(anchorProvider: @escaping () -> SmbCloudPresentationAnchor) async {
        guard let webAuth else {
            errorMessage = errorMessage ?? "The smbCloud web auth client could not be created."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await webAuth.login(
                presentationAnchorProvider: anchorProvider,
                credentialsManager: credentialsManager
            )
            self.session = session

            let user = try await webAuth.userInfo(session: session)
            userEmail = user.email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try webAuth?.clearSession(credentialsManager: credentialsManager)
            session = nil
            userEmail = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
