# Quick Start — macOS

This guide shows hosted smbCloud Auth in a macOS app using `SmbCloudWebAuth` and `SmbCloudCredentialsManager`.

## 1. Add the package

Add `https://github.com/smbcloudXYZ/smbcloud-auth-swift` to your macOS app.

## 2. Configure a callback URL

Use a callback URL such as:

- `mymacapp://auth/callback`

Register that URL scheme for your app so the hosted auth callback returns to the application.

## 3. Build a small store

```swift
import AppKit
import SmbCloudAuth
import SwiftUI

@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var session: SmbCloudSession?
    @Published private(set) var email: String?
    @Published private(set) var errorMessage: String?

    private let webAuth = SmbCloudWebAuth(
        environment: .production,
        oidcClientId: "YOUR_OIDC_CLIENT_ID",
        redirectURL: URL(string: "mymacapp://auth/callback")!
    )
    private let credentialsManager = SmbCloudCredentialsManager(
        service: "com.example.mymacapp.smbcloud-auth"
    )

    func restoreSession() {
        do {
            session = try credentialsManager.currentValidSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn() async {
        do {
            let session = try await webAuth.login(
                presentationAnchorProvider: {
                    NSApplication.shared.keyWindow ?? NSWindow()
                },
                credentialsManager: credentialsManager
            )
            self.session = session

            let user = try await webAuth.userInfo(session: session)
            email = user.email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try webAuth.clearSession(credentialsManager: credentialsManager)
            session = nil
            email = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## 4. Use it from SwiftUI

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var authStore = AuthenticationStore()

    var body: some View {
        VStack(spacing: 12) {
            if let email = authStore.email {
                Text("Signed in as \(email)")
            } else if authStore.session != nil {
                Text("Signed in")
            } else {
                Text("Signed out")
            }

            HStack {
                Button("Sign In") {
                    Task {
                        await authStore.signIn()
                    }
                }

                Button("Sign Out") {
                    authStore.signOut()
                }
                .disabled(authStore.session == nil)
            }

            if let errorMessage = authStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(width: 360)
        .task {
            authStore.restoreSession()
        }
    }
}
```

## Notes

- Supply a real public client ID from smbCloud Auth.
- Use an explicit Keychain `service` value for your app.
- Do not ship an `app_secret` in the macOS app.
- Do not show or log raw access tokens in production UI.
- `clearSession()` and `logout()` currently clear local stored credentials only.
- If you need native email/password forms, keep confidential auth credentials on your backend.

## Related docs

- `Docs/QuickStart-iOS.md`
- `Docs/Migration-From-Proxy-Native-Forms.md`
