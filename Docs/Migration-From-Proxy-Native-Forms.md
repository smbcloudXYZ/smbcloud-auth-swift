# Migration guide — from proxy/native-form auth to hosted auth

This guide is for teams currently using:

- a backend or BFF proxy for login/signup
- native email/password forms in the app
- confidential smbCloud Auth credentials stored on the server

and who want to move Apple apps toward the hosted public-client SDK model.

## When to migrate

Move to hosted auth when:

- your Apple app is a public client
- you want to stop maintaining auth proxy glue in the app layer
- you want browser/session based login with PKCE
- you do not need a custom native email/password screen as the primary flow

Keep the proxy/BFF model when:

- your product requires native credential forms
- your backend owns broader session orchestration
- you need server-managed trust boundaries beyond public-client hosted auth

## Old model

1. user enters email and password into the app
2. app sends credentials to your backend
3. backend uses confidential smbCloud Auth credentials
4. backend returns an app-safe response

## Hosted auth model

1. app calls `SmbCloudWebAuth.login(...)`
2. SDK opens hosted auth in `ASWebAuthenticationSession`
3. user completes login in the system browser session
4. SDK validates callback `state` and exchanges the code with PKCE
5. app persists the returned `SmbCloudSession`
6. app loads profile data with `userInfo(...)`

## Migration plan

### 1. Keep server-side auth for native forms if still needed

Do not remove your proxy if the product still depends on native credential entry.
Hosted auth and proxy-based auth can coexist during migration.

### 2. Add a public client in smbCloud Auth

The Apple app should use a public client identifier and a callback URL such as:

- `myapp://auth/callback`

Do not copy confidential secrets into the app.

### 3. Replace app-side login orchestration

Replace custom login glue with:

- `SmbCloudWebAuth`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient` if you want standalone profile fetches

### 4. Move local session storage to Keychain

Persist `SmbCloudSession` with `SmbCloudCredentialsManager` instead of keeping access tokens in plaintext storage.

### 5. Update your UX copy

Hosted auth changes the user experience from a native email/password form to a system browser-backed sign-in flow.
Prepare copy, onboarding, and support docs accordingly.

## What changes in app code

### Before

- app owns email/password UI
- app talks to your backend for auth
- backend owns smbCloud Auth credentials

### After

- app launches hosted auth via `SmbCloudWebAuth.login(...)`
- SDK handles PKCE and callback validation
- app stores `SmbCloudSession`
- app fetches user info with the access token

## Security benefits

- no confidential smbCloud Auth secret inside the shipped app
- no embedded webview login flow
- PKCE protects the public-client authorization code flow
- system browser sessions align with Apple platform expectations

## What does not change

If you still need native forms, a BFF/proxy remains the correct architecture.
This SDK does not try to replace secure server-side confidential flows for those cases.

## Recommended rollout

1. introduce hosted auth for new sign-ins
2. keep proxy-based flows for legacy/native-form users if necessary
3. migrate session restoration to `SmbCloudCredentialsManager`
4. retire app-specific auth glue once the hosted path is the default

## Related docs

- `Docs/QuickStart-iOS.md`
- `Docs/QuickStart-macOS.md`
