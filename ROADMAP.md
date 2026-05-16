# smbCloud Auth for Swift roadmap

## Product goal

Build the default Apple-platform SDK for smbCloud Auth.

That means developers should be able to integrate authentication into an iPhone, iPad, Mac, Apple TV, or visionOS app with a clear, secure, Apple-native workflow.

The product needs to be:

- secure for public clients
- easy to adopt
- easy to document
- easy to distribute via Swift Package Manager
- opinionated around Apple-native auth UX

## Core positioning

`smbcloud-auth-swift` should be the **public-client SDK**.

It should optimize for:

- hosted auth
- OIDC Authorization Code + PKCE
- `ASWebAuthenticationSession`
- token/session management
- profile lookup
- logout

It should **not** optimize for embedding confidential-client secrets into shipped apps.

## Product split

### Public Apple SDK

Repository:

- `smbcloud-auth-swift`

Audience:

- iOS developers
- macOS developers
- tvOS developers
- visionOS developers
- open-source app maintainers
- App Store product teams

Primary value proposition:

- secure hosted login for Apple platforms without shipping a client secret

### Confidential / server-side SDKs

Audience:

- server-side Swift
- backend services
- internal tooling
- trusted CI / automation

These flows can continue to exist in Rust or other SDKs, but they should not be the main product story for the public Apple package.

## Version roadmap

## v0.x — foundation

Status:

- in progress

What exists today:

- low-level Rust-backed OIDC helpers
- PKCE request generation
- callback parsing
- token exchange
- userinfo
- Apple Sign-In helpers

What is missing:

- polished Apple-native public API
- browser/session orchestration
- credentials storage
- production-ready docs and examples

## v1.0 — public-client MVP

Status:

- core API surface implemented in developer preview

Goal:

Ship the first sellable public-client SDK for Apple apps.

### Implemented API surface

- `SmbCloudWebAuth`
- `SmbCloudSession`
- `SmbCloudCredentialsManager`
- `SmbCloudUserInfoClient`

### Implemented capabilities

- start hosted login with PKCE
- open `ASWebAuthenticationSession`
- handle callback URL
- exchange authorization code
- fetch user profile
- local session persistence
- local logout/session clearing helper

### Remaining polish before stable v1

- Quick Start for iOS
- Quick Start for macOS
- example app
- migration guide for teams coming from proxy/native-form auth
- release artifact parity across Apple platforms
- logout / revocation story beyond local session clearing
- security guidance refresh for the final API shape

### MVP example shape

```/dev/null/swift-example.swift#L1-L20
let webAuth = SmbCloudWebAuth(
    domain: "auth.smbcloud.xyz",
    clientId: "YOUR_PUBLIC_CLIENT_ID",
    redirectURL: URL(string: "myapp://auth/callback")!
)

let session = try await webAuth.login(
    presenter: presenter,
    scope: ["openid", "profile", "email"]
)

let user = try await webAuth.userInfo(accessToken: session.accessToken)
try credentialsManager.store(session)
```

## v1.1 — production polish

### Developer experience

- better error types
- strongly typed session models
- clock-skew handling
- refresh token helpers if supported
- cleaner cancellation behavior
- better logging hooks

### Apple integrations

- SwiftUI examples
- UIKit examples
- scene-aware callback handling
- universal link guidance
- custom scheme guidance

### Operations

- stable release workflow
- signed XCFramework release process
- checksum automation in Swift package repo

## v1.2 — enterprise / BFF support docs

This package should still recommend hosted auth for public apps, but document how teams can combine it with a backend/BFF when they want:

- native login forms
- session cookies
- custom trust boundaries
- server-managed auth orchestration

This should be a **documented architecture path**, not the core package identity.

## v2 — broader Apple auth platform

Potential additions:

- multi-tenant helpers
- organizations/workspaces support
- passkey/WebAuthn coordination if smbCloud Auth adds it
- richer logout/session revocation flows
- first-class secure token storage abstractions
- diagnostic tools for callback and state mismatches

## Packaging roadmap

## Distribution model

Primary distribution should remain:

- Swift Package Manager

Artifact strategy:

- prebuilt XCFramework zip attached to GitHub releases
- generated Swift bindings checked into repo
- local path development mode for sibling `smbcloud-cli` checkout

## CI/CD expectations

- Apple platform build validation
- XCFramework release automation
- checksum publishing
- release notes generation
- tagged semver releases

## Go-to-market

## Who buys this

Not literally as a separate SKU at first — the SDK makes smbCloud Auth itself more sellable.

It helps sell smbCloud Auth to:

- indie Apple developers
- startups building Apple-first products
- enterprise teams with internal Apple apps
- agencies shipping branded apps for clients

## What makes it sellable

A sellable auth SDK is not just “it compiles”.
It must communicate:

- secure defaults
- clear docs
- familiar API design
- low integration friction
- a future-proof auth model

## Product standard

The product standard is:

> a junior Apple developer should be able to integrate login in an afternoon without accidentally shipping a secret.

## Success criteria

The SDK is on the right track when:

- public examples never require `app_secret`
- the default sample app uses hosted auth + PKCE
- docs explicitly forbid shipping confidential secrets in clients
- SwiftUI sample apps feel natural
- teams can adopt it without building their own auth glue layer first
