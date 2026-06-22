# Hosted Login Example

This folder contains a small SwiftUI-oriented example of the v1 MVP API surface:

- `SmbCloudWebAuth`
- `SmbCloudSession`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient`

## Files

- `Package.swift` — standalone example package manifest
- `Sources/HostedLoginExample/HostedLoginExampleApp.swift` — SwiftUI app entry point
- `Sources/HostedLoginExample/AuthenticationStore.swift` — minimal observable auth state container
- `Sources/HostedLoginExample/HostedLoginView.swift` — simple signed-in / signed-out SwiftUI view

## Configuration you must replace

Before using the example, replace:

- `YOUR_OIDC_CLIENT_ID`
- `hostedloginexample://auth/callback`
- Keychain service name

## Build locally

```bash
swift build --package-path Examples/HostedLoginExample
```

## Security note

Use a public client ID only.
Do not embed an smbCloud Auth `app_secret` in a shipped Apple app.
