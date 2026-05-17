SHELL := /bin/sh

SWIFT_REPO := $(CURDIR)
CLI_REPO ?= $(abspath ../smbcloud-cli)
CARGO_MANIFEST := $(CLI_REPO)/Cargo.toml
APPLE_CRATE_MANIFEST := $(CLI_REPO)/crates/smbcloud-auth-sdk-apple/Cargo.toml
BINDGEN := $(CLI_REPO)/target/release/uniffi-bindgen

RUST_STABLE ?= +$(shell sed -n 's/^channel = "\(.*\)"/\1/p' "$(CLI_REPO)/rust-toolchain.toml" | head -n 1)
RUST_NIGHTLY ?= +nightly

IOS_DEPLOYMENT_TARGET ?= 16.0
MACOS_DEPLOYMENT_TARGET ?= 14.0
TVOS_DEPLOYMENT_TARGET ?= 16.0
VISIONOS_DEPLOYMENT_TARGET ?= 1.0

LOCAL_DIR := $(SWIFT_REPO)/.local
GENERATED_DIR := $(LOCAL_DIR)/generated/SmbCloudAuth
HEADERS_DIR := $(LOCAL_DIR)/Headers
FRAMEWORK_STAGING_DIR := $(LOCAL_DIR)/frameworks
FRAMEWORK_DIR := $(SWIFT_REPO)/smbcloud_authFFI.xcframework
SLICE_FRAMEWORK_NAME := smbcloud_authFFI.framework
FRAMEWORK_BINARY_NAME := smbcloud_authFFI
SWIFT_GLUE := $(SWIFT_REPO)/Sources/SmbCloudAuthFFI/smbcloud_auth.swift
LOCAL_FFI_MARKER := $(LOCAL_DIR)/use-local-ffi

LIB_NAME := libsmbcloud_auth.a
SUPPORTED_PLATFORMS := ios macos tvos visionos

.PHONY: help platform ios macos tvos visionos validate build-bindgen prepare generate-swift stage-framework activate-local-ffi deactivate-local-ffi clean verify verify-example verify-apple-destinations verify-apple-destination

help:
	@printf '%s\n' \
	  'SmbCloudAuth Swift — local Apple-platform builds' \
	  '' \
	  'Usage:' \
	  '  make ios                     Build smbcloud_authFFI.xcframework for iOS device + simulator' \
	  '  make macos                   Build smbcloud_authFFI.xcframework for macOS (Apple silicon)' \
	  '  make tvos                    Build smbcloud_authFFI.xcframework for tvOS device + simulator' \
	  '  make visionos                Build smbcloud_authFFI.xcframework for visionOS device + simulator' \
	  '  make verify                  Build + test the main Swift package and build the example app package' \
	  '  make verify-example          Build the packaged macOS example app' \
	  '  make verify-apple-destinations  Build the public package for iOS, tvOS, and visionOS generic destinations' \
	  '  make deactivate-local-ffi    Hide the optional local SmbCloudAuthFFI product' \
	  '' \
	  'Artifacts:' \
	  '  smbcloud_authFFI.xcframework/' \
	  '  Sources/SmbCloudAuthFFI/smbcloud_auth.swift (regenerated from the local Rust build)' \
	  '' \
	  'Notes:' \
	  '  The public SmbCloudAuth product is pure Swift and always available.' \
	  '  Local Rust/UniFFI builds enable the optional SmbCloudAuthFFI product.' \
	  '' \
	  'Optional overrides:' \
	  '  CLI_REPO=/absolute/path/to/smbcloud-cli'

platform:
	@test -n "$(PLATFORM)" || { echo "Set PLATFORM=$(SUPPORTED_PLATFORMS)"; exit 1; }
	@case "$(PLATFORM)" in \
	  ios|macos|tvos|visionos) $(MAKE) "$(PLATFORM)" ;; \
	  *) echo "Unsupported PLATFORM='$(PLATFORM)'. Expected one of: $(SUPPORTED_PLATFORMS)"; exit 1 ;; \
	esac

validate:
	@test -f "$(CARGO_MANIFEST)" || { echo "Could not find workspace Cargo.toml at $(CARGO_MANIFEST). Set CLI_REPO."; exit 1; }
	@test -f "$(APPLE_CRATE_MANIFEST)" || { echo "Could not find smbcloud-auth-sdk-apple crate at $(APPLE_CRATE_MANIFEST)"; exit 1; }
	@test -d "$(SWIFT_REPO)/Sources/SmbCloudAuth" || { echo "Run make from the smbcloud-auth Swift package root."; exit 1; }

build-bindgen: validate
	cargo $(RUST_STABLE) build --manifest-path "$(APPLE_CRATE_MANIFEST)" --features bindgen --bin uniffi-bindgen --release

prepare:
	@rm -rf "$(FRAMEWORK_DIR)" "$(GENERATED_DIR)" "$(HEADERS_DIR)" "$(FRAMEWORK_STAGING_DIR)" "$(LOCAL_FFI_MARKER)"
	@mkdir -p "$(GENERATED_DIR)" "$(HEADERS_DIR)" "$(FRAMEWORK_STAGING_DIR)" "$(SWIFT_REPO)/Sources/SmbCloudAuthFFI"

generate-swift:
	@test -n "$(BINDGEN_INPUT)" || { echo "BINDGEN_INPUT is required"; exit 1; }
	cd "$(CLI_REPO)" && "$(BINDGEN)" generate --library "$(BINDGEN_INPUT)" --language swift --out-dir "$(GENERATED_DIR)"
	cp "$(GENERATED_DIR)/smbcloud_auth.swift" "$(SWIFT_GLUE)"
	cp "$(GENERATED_DIR)/smbcloud_authFFI.h" "$(HEADERS_DIR)/smbcloud_authFFI.h"
	@echo "Updated $(SWIFT_GLUE)"

activate-local-ffi:
	@mkdir -p "$(LOCAL_DIR)"
	@touch "$(LOCAL_FFI_MARKER)"
	@echo "Enabled local SmbCloudAuthFFI product"

deactivate-local-ffi:
	@rm -f "$(LOCAL_FFI_MARKER)"
	@echo "Disabled local SmbCloudAuthFFI product"

stage-framework:
	@test -n "$(LIB_INPUT)" || { echo "LIB_INPUT is required"; exit 1; }
	@test -n "$(FRAMEWORK_OUTPUT)" || { echo "FRAMEWORK_OUTPUT is required"; exit 1; }
	@rm -rf "$(FRAMEWORK_OUTPUT)"
	@mkdir -p "$(FRAMEWORK_OUTPUT)/Headers" "$(FRAMEWORK_OUTPUT)/Modules"
	cp "$(LIB_INPUT)" "$(FRAMEWORK_OUTPUT)/$(FRAMEWORK_BINARY_NAME)"
	cp "$(HEADERS_DIR)/smbcloud_authFFI.h" "$(FRAMEWORK_OUTPUT)/Headers/smbcloud_authFFI.h"
	@printf '%s\n' \
	  'framework module smbcloud_authFFI {' \
	  '    header "smbcloud_authFFI.h"' \
	  '    export *' \
	  '    use "Darwin"' \
	  '    use "_Builtin_stdbool"' \
	  '    use "_Builtin_stdint"' \
	  '}' > "$(FRAMEWORK_OUTPUT)/Modules/module.modulemap"
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0">' \
	  '<dict>' \
	  '  <key>CFBundleIdentifier</key>' \
	  '  <string>xyz.smbcloud.smbcloud-auth-ffi</string>' \
	  '  <key>CFBundleName</key>' \
	  '  <string>$(FRAMEWORK_BINARY_NAME)</string>' \
	  '  <key>CFBundleExecutable</key>' \
	  '  <string>$(FRAMEWORK_BINARY_NAME)</string>' \
	  '  <key>CFBundlePackageType</key>' \
	  '  <string>FMWK</string>' \
	  '  <key>CFBundleShortVersionString</key>' \
	  '  <string>1.0.1</string>' \
	  '  <key>CFBundleVersion</key>' \
	  '  <string>1</string>' \
	  '</dict>' \
	  '</plist>' > "$(FRAMEWORK_OUTPUT)/Info.plist"

ios: build-bindgen prepare
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-ios --release --lib --crate-type staticlib
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-ios-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-ios/release/$(LIB_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-ios/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/ios/$(SLICE_FRAMEWORK_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-ios-sim/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/ios-sim/$(SLICE_FRAMEWORK_NAME)"
	xcodebuild -create-xcframework \
	  -framework "$(FRAMEWORK_STAGING_DIR)/ios/$(SLICE_FRAMEWORK_NAME)" \
	  -framework "$(FRAMEWORK_STAGING_DIR)/ios-sim/$(SLICE_FRAMEWORK_NAME)" \
	  -output "$(FRAMEWORK_DIR)"
	$(MAKE) activate-local-ffi
	@echo "Built $(FRAMEWORK_DIR) for iOS"

macos: build-bindgen prepare
	MACOSX_DEPLOYMENT_TARGET=$(MACOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-darwin --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-darwin/release/$(LIB_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-darwin/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/macos/$(SLICE_FRAMEWORK_NAME)"
	xcodebuild -create-xcframework \
	  -framework "$(FRAMEWORK_STAGING_DIR)/macos/$(SLICE_FRAMEWORK_NAME)" \
	  -output "$(FRAMEWORK_DIR)"
	$(MAKE) activate-local-ffi
	@echo "Built $(FRAMEWORK_DIR) for macOS"

tvos: build-bindgen prepare
	TVOS_DEPLOYMENT_TARGET=$(TVOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-tvos --release --lib --crate-type staticlib
	TVOS_DEPLOYMENT_TARGET=$(TVOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-tvos-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-tvos/release/$(LIB_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-tvos/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/tvos/$(SLICE_FRAMEWORK_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-tvos-sim/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/tvos-sim/$(SLICE_FRAMEWORK_NAME)"
	xcodebuild -create-xcframework \
	  -framework "$(FRAMEWORK_STAGING_DIR)/tvos/$(SLICE_FRAMEWORK_NAME)" \
	  -framework "$(FRAMEWORK_STAGING_DIR)/tvos-sim/$(SLICE_FRAMEWORK_NAME)" \
	  -output "$(FRAMEWORK_DIR)"
	$(MAKE) activate-local-ffi
	@echo "Built $(FRAMEWORK_DIR) for tvOS"

visionos: build-bindgen prepare
	XROS_DEPLOYMENT_TARGET=$(VISIONOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-visionos --release --lib --crate-type staticlib
	XROS_DEPLOYMENT_TARGET=$(VISIONOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-visionos-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-visionos/release/$(LIB_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-visionos/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/visionos/$(SLICE_FRAMEWORK_NAME)"
	$(MAKE) stage-framework LIB_INPUT="$(CLI_REPO)/target/aarch64-apple-visionos-sim/release/$(LIB_NAME)" FRAMEWORK_OUTPUT="$(FRAMEWORK_STAGING_DIR)/visionos-sim/$(SLICE_FRAMEWORK_NAME)"
	xcodebuild -create-xcframework \
	  -framework "$(FRAMEWORK_STAGING_DIR)/visionos/$(SLICE_FRAMEWORK_NAME)" \
	  -framework "$(FRAMEWORK_STAGING_DIR)/visionos-sim/$(SLICE_FRAMEWORK_NAME)" \
	  -output "$(FRAMEWORK_DIR)"
	$(MAKE) activate-local-ffi
	@echo "Built $(FRAMEWORK_DIR) for visionOS"

verify:
	swift build
	swift test
	$(MAKE) verify-example

verify-example:
	swift build --package-path Examples/HostedLoginExample

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
	rm -rf "$(FRAMEWORK_DIR)" "$(LOCAL_DIR)"
	rm -f "$(SWIFT_GLUE)"
	@echo "Removed local SmbCloudAuth Swift build artifacts"
