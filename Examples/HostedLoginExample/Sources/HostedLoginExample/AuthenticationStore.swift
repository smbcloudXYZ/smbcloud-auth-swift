import SmbCloudAuth
import SwiftUI

@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var session: SmbCloudSession?
    @Published private(set) var userEmail: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let webAuth = SmbCloudWebAuth(
        environment: .production,
        oidcClientId: "YOUR_OIDC_CLIENT_ID",
        redirectURL: URL(string: "hostedloginexample://auth/callback")!
    )
    private let credentialsManager = SmbCloudCredentialsManager(
        service: "com.example.hosted-login-example.smbcloud-auth"
    )

    func restoreSession() {
        do {
            session = try credentialsManager.currentValidSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(anchorProvider: @escaping () -> SmbCloudPresentationAnchor) async {
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
            try webAuth.clearSession(credentialsManager: credentialsManager)
            session = nil
            userEmail = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
