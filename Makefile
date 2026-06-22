SHELL := /bin/sh

SWIFT_REPO := $(CURDIR)
LOCAL_DIR := $(SWIFT_REPO)/.local

.PHONY: help verify verify-example verify-linux verify-apple-destinations verify-apple-destination clean

help:
	@printf '%s\n' \
	  'SmbCloudAuth Swift — pure-Swift SDK' \
	  '' \
	  'Usage:' \
	  '  make verify                     Build + test the package and build the example app' \
	  '  make verify-example             Build the packaged macOS example app' \
	  '  make verify-linux               Build + test AuthCore on a non-Apple toolchain' \
	  '  make verify-apple-destinations  Build the package for iOS, tvOS, and visionOS' \
	  '  make clean                      Remove local build artifacts' \
	  '' \
	  'Layering:' \
	  '  AuthCore     cross-platform (Apple/Linux/Windows/Android) headless core,' \
	  '               a native Swift port of smbcloud-cli/crates/smbcloud-auth-sdk.' \
	  '  SmbCloudAuth Apple UI layer (hosted login + Keychain) on top of AuthCore.' \
	  '  Both are pure Swift — no Rust/UniFFI artifacts required.'

verify:
	swift build
	swift test
	$(MAKE) verify-example

verify-example:
	swift build --package-path Examples/HostedLoginExample

# Cross-platform check: AuthCore (and the rest of the package) must build and
# test on non-Apple toolchains such as Linux, Windows, and Android.
verify-linux:
	swift build
	swift build --target AuthCore
	swift test

verify-apple-destinations:
	$(MAKE) verify-apple-destination PLATFORM=ios
	$(MAKE) verify-apple-destination PLATFORM=tvos
	$(MAKE) verify-apple-destination PLATFORM=visionos

verify-apple-destination:
	@test -n "$(PLATFORM)" || { echo "Set PLATFORM=ios|tvos|visionos"; exit 1; }
	@case "$(PLATFORM)" in \
	  ios) destination="generic/platform=iOS"; derived_data="$(LOCAL_DIR)/verify-ios" ;; \
	  tvos) destination="generic/platform=tvOS"; derived_data="$(LOCAL_DIR)/verify-tvos" ;; \
	  visionos) destination="generic/platform=visionOS"; derived_data="$(LOCAL_DIR)/verify-visionos" ;; \
	  *) echo "Unsupported PLATFORM='$(PLATFORM)'. Expected one of: ios tvos visionos"; exit 1 ;; \
	esac; \
	xcodebuild -quiet -scheme SmbCloudAuth -destination "$${destination}" -derivedDataPath "$${derived_data}" build

clean:
	rm -rf "$(LOCAL_DIR)"
	@echo "Removed local SmbCloudAuth Swift build artifacts"
