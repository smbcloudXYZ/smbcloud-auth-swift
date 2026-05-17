# Security guidance for smbCloud Auth Swift

## Public-client rule

If your app ships to users, assume anything inside the client can be extracted.

That includes:

- values in `Info.plist`
- values in bundled config files
- environment-derived values copied into the app bundle
- strings inside the binary
- local cache or storage values

Because of that:

**Do not embed an smbCloud Auth `app_secret` inside a public Apple app.**

## Recommended model for Apple apps

Use:

- hosted auth
- system browser sessions
- OIDC Authorization Code + PKCE
- Keychain-backed local session storage

On Apple platforms this generally means:

- `ASWebAuthenticationSession`
- a custom URL scheme or universal link callback
- token exchange after the callback returns
- persisting `SmbCloudSession` with `SmbCloudCredentialsManager`

## Do not use embedded browser auth

Avoid running auth inside embedded webviews such as:

- `WKWebView`
- other in-app embedded browser containers

Use system browser-backed auth sessions instead.

## If you need native login forms

If your product requires a fully native email/password screen, do **not** solve that by shipping a secret in the app.

Instead:

- send credentials to your backend/BFF
- keep smbCloud Auth confidential credentials on the server
- let the backend proxy or orchestrate the auth flow

## SDK positioning

`smbcloud-auth-swift` should be used as a **public-client SDK**.

That means the preferred long-term shape is:

- hosted auth
- PKCE
- session/token helpers
- userinfo/logout helpers

not:

- confidential-client secret-based login inside the shipped app

## Local credential storage

If you persist sessions locally, prefer Keychain storage.

The SDK provides `SmbCloudCredentialsManager` for that purpose.
Use an explicit per-app `service` name so multiple apps or test targets do not accidentally share the same stored session namespace.

## Logout semantics

The current SDK `logout()` helper is a local session-clearing helper.
It clears persisted credentials through `SmbCloudCredentialsManager`, but it does not yet perform remote token revocation.

## Operational guidance

For development:

- use separate dev credentials
- prefer local-only configuration
- never commit secrets into the repo
- use a development-specific Keychain service name if you store sessions locally

For production:

- use public-client identifiers only in the app
- keep confidential secrets in server-side systems
- audit example code to ensure no public sample embeds secrets
- review callback URL handling and Keychain service naming before shipping
