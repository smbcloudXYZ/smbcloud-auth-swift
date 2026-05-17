# Quick Start — iOS

This guide shows the hosted smbCloud Auth flow for an iPhone or iPad app using:

- `SmbCloudWebAuth`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient`

## 1. Add the package

Add `https://github.com/smbcloudXYZ/smbcloud-auth-swift` in Xcode or Swift Package Manager.

## 2. Register a callback URL scheme

Your app needs a custom callback URL such as:

- `myapp://auth/callback`

Add the URL scheme in your app target settings so iOS can route the hosted auth callback back into the app.

## 3. Create a small auth store

Use one public client ID from smbCloud Auth.
Do not embed an `app_secret` in the app.

```swift
import SmbCloudAuth
import SwiftUI

@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var session: SmbCloudSession?
    @Published private(set) var email: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let webAuth = try! SmbCloudWebAuth(
        domain: "api.smbcloud.xyz",
        clientId: "YOUR_PUBLIC_CLIENT_ID",
        redirectURL: URL(string: "myapp://auth/callback")!
    )
    private let credentialsManager = SmbCloudCredentialsManager(
        service: "com.example.myapp.smbcloud-auth"
    )

    func restoreSession() {
        do {
            session = try credentialsManager.currentValidSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(anchor: @escaping () -> SmbCloudPresentationAnchor) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await webAuth.login(
                presentationAnchorProvider: anchor,
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## 4. Provide a presentation anchor

For SwiftUI on iOS, the simplest approach is to return the current key window.

```swift
import UIKit

func currentPresentationAnchor() -> UIWindow {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow } ?? UIWindow()
}
```

## 5. Build a simple screen

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var authStore = AuthenticationStore()

    var body: some View {
        VStack(spacing: 16) {
            if let session = authStore.session {
                Text("Signed in")
                Text(session.accessToken)
                    .font(.footnote.monospaced())
                    .lineLimit(2)
                if let email = authStore.email {
                    Text(email)
                }
                Button("Sign Out") {
                    authStore.signOut()
                }
            } else {
                Button("Continue with smbCloud") {
                    Task {
                        await authStore.signIn {
                            currentPresentationAnchor()
                        }
                    }
                }
            }

            if let errorMessage = authStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            authStore.restoreSession()
        }
    }
}
```

## 6. What happens during login

1. `SmbCloudWebAuth` creates a PKCE authorization request.
2. `ASWebAuthenticationSession` opens the hosted smbCloud login page.
3. smbCloud Auth redirects to your app callback URL.
4. The SDK validates `state`, exchanges the authorization code, and returns `SmbCloudSession`.
5. `SmbCloudCredentialsManager` stores the session in Keychain.

## Notes

- Prefer an explicit Keychain `service` value per app.
- `logout()` currently clears local stored credentials. It does not revoke tokens remotely.
- Hosted web login requires `ASWebAuthenticationSession`, so use iOS 16+.
- If your product needs native email/password forms, send those credentials to your backend or BFF instead of embedding confidential credentials in the app.

## Related docs

- `Docs/QuickStart-macOS.md`
- `Docs/Migration-From-Proxy-Native-Forms.md`
- `SECURITY.md`
