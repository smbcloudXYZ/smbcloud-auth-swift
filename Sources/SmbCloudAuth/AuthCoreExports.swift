// `SmbCloudAuth` is the Apple-platform UI layer on top of the cross-platform
// `AuthCore` engine. Re-export `AuthCore` so `import SmbCloudAuth` call sites
// also see `AuthCoreClient`, `OIDC`, `SmbCloudSession`, `ClientCredentials`,
// `SmbCloudError`, `SmbCloudCredentialsStore`, and friends without an extra
// import.
@_exported import AuthCore
