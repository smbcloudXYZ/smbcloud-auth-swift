// `SmbCloudAuth` is the Apple-platform UI layer on top of the cross-platform
// `AuthCore` engine. Re-export `AuthCore` so existing `import SmbCloudAuth`
// call sites keep seeing `SmbCloudSession`, `SmbCloudUserInfo`,
// `SmbCloudClientError`, `SmbCloudAuthClient`, `SmbCloudCredentialsStore`,
// `SmbCloudUserInfoClient`, and friends without an extra import.
@_exported import AuthCore
