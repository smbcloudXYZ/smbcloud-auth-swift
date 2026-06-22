# Release process

`smbcloud-auth-swift` now ships as a source-based Swift Package.

That means the public `SmbCloudAuth` product does not need a remote XCFramework artifact to be published.
The package is consumable directly from the Git tag.

## What gets released

Public products (both pure Swift):

- `AuthCore` — cross-platform headless engine
- `SmbCloudAuth` — Apple UI layer on top of `AuthCore`

There is no Rust/UniFFI artifact to build or publish; the package is fully
source-based.

## CI validation

GitHub Actions validates release candidates with:

- `make verify`
- `make verify-apple-destination PLATFORM=ios`
- `make verify-apple-destination PLATFORM=tvos`
- `make verify-apple-destination PLATFORM=visionos`

That covers:

- the main Swift package build
- the main Swift package tests
- the packaged macOS example app build
- generic Apple destination builds for iOS, tvOS, and visionOS

## Tagging a release

Create and push a semver tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will:

1. check out the tagged revision
2. run `make verify`
3. create a GitHub Release for the tag

## Manual release dispatch

You can also run the `Release` workflow manually and provide a tag such as `v1.0.0`.

## Local pre-release verification

Before tagging, run:

```bash
make verify
make verify-apple-destinations
```
