# Release process

`smbcloud-auth-swift` now ships as a source-based Swift Package.

That means the public `SmbCloudAuth` product does not need a remote XCFramework artifact to be published.
The package is consumable directly from the Git tag.

## What gets released

Public product:

- `SmbCloudAuth`

Optional local development product:

- `SmbCloudAuthFFI`

`SmbCloudAuthFFI` is for sibling-repo development when you build the local Rust + UniFFI artifacts yourself.
It is not required for normal package consumers.

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

```/dev/null/bash.txt#L1-L2
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

```/dev/null/bash.txt#L1-L2
make verify
make verify-apple-destinations
```

## Local optional FFI development

If you are working alongside `smbcloud-cli`, you can generate the optional local UniFFI/XCFramework layer with:

```/dev/null/bash.txt#L1-L4
make ios
make macos
make tvos
make visionos
```

That enables the local `SmbCloudAuthFFI` product for development.
The public release flow does not depend on those artifacts.
