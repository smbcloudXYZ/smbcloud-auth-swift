import SwiftUI

@main
struct HostedLoginExampleApp: App {
    var body: some Scene {
        WindowGroup {
            HostedLoginView(
                presentationAnchorProvider: {
                    currentPresentationAnchor()
                }
            )
        }
    }
}
