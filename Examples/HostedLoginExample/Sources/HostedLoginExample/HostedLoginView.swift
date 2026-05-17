import AppKit
import SmbCloudAuth
import SwiftUI

struct HostedLoginView: View {
    @StateObject private var authenticationStore = AuthenticationStore()
    let presentationAnchorProvider: () -> SmbCloudPresentationAnchor

    var body: some View {
        VStack(spacing: 16) {
            Text("smbCloud Hosted Login Example")
                .font(.title2)

            if let userEmail = authenticationStore.userEmail {
                Text(userEmail)
                    .font(.headline)
            } else if authenticationStore.session != nil {
                Text("Signed in")
                    .font(.headline)
            } else {
                Text("Signed out")
                    .font(.headline)
            }

            if let session = authenticationStore.session {
                Text(session.accessToken)
                    .font(.footnote.monospaced())
                    .lineLimit(2)
            }

            HStack {
                Button(authenticationStore.isLoading ? "Loading…" : "Continue with smbCloud") {
                    Task {
                        await authenticationStore.signIn(
                            anchorProvider: presentationAnchorProvider
                        )
                    }
                }
                .disabled(authenticationStore.isLoading)

                Button("Sign Out") {
                    authenticationStore.signOut()
                }
                .disabled(authenticationStore.session == nil)
            }

            if let errorMessage = authenticationStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(width: 460)
        .task {
            authenticationStore.restoreSession()
        }
    }
}

@MainActor
func currentPresentationAnchor() -> NSWindow {
    NSApplication.shared.keyWindow ?? NSWindow()
}
