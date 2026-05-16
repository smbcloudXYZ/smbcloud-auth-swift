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
FRAMEWORK_DIR := $(SWIFT_REPO)/SmbCloudAuthFramework.xcframework
SWIFT_GLUE := $(SWIFT_REPO)/Sources/SmbCloudAuth/smbcloud_auth.swift

LIB_NAME := libsmbcloud_auth.a

SUPPORTED_PLATFORMS := ios macos tvos visionos

.PHONY: help platform ios macos tvos visionos validate build-bindgen prepare generate-swift clean

help:
	@printf '%s\n' \
	  'SmbCloudAuth Swift — local Apple-platform builds' \
	  '' \
	  'Usage:' \
	  '  make ios        Build SmbCloudAuthFramework.xcframework for iOS device + simulator' \
	  '  make macos      Build SmbCloudAuthFramework.xcframework for macOS (Apple silicon)' \
	  '  make tvos       Build SmbCloudAuthFramework.xcframework for tvOS device + simulator' \
	  '  make visionos   Build SmbCloudAuthFramework.xcframework for visionOS device + simulator' \
	  '' \
	  'Artifacts:' \
	  '  SmbCloudAuthFramework.xcframework/' \
	  '  Sources/SmbCloudAuth/smbcloud_auth.swift (regenerated from the local Rust build)' \
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
	@rm -rf "$(FRAMEWORK_DIR)" "$(GENERATED_DIR)" "$(HEADERS_DIR)"
	@mkdir -p "$(GENERATED_DIR)" "$(HEADERS_DIR)"

generate-swift:
	@test -n "$(BINDGEN_INPUT)" || { echo "BINDGEN_INPUT is required"; exit 1; }
	cd "$(CLI_REPO)" && "$(BINDGEN)" generate --library "$(BINDGEN_INPUT)" --language swift --out-dir "$(GENERATED_DIR)"
	cp "$(GENERATED_DIR)/smbcloud_auth.swift" "$(SWIFT_GLUE)"
	cp "$(GENERATED_DIR)/smbcloud_authFFI.h" "$(HEADERS_DIR)/smbcloud_authFFI.h"
	cp "$(GENERATED_DIR)/smbcloud_authFFI.modulemap" "$(HEADERS_DIR)/module.modulemap"
	@echo "Updated $(SWIFT_GLUE)"

ios: build-bindgen prepare
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-ios --release --lib --crate-type staticlib
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-ios-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-ios/release/$(LIB_NAME)"
	xcodebuild -create-xcframework \
	  -library "$(CLI_REPO)/target/aarch64-apple-ios/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -library "$(CLI_REPO)/target/aarch64-apple-ios-sim/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -output "$(FRAMEWORK_DIR)"
	@echo "Built $(FRAMEWORK_DIR) for iOS"

macos: build-bindgen prepare
	MACOSX_DEPLOYMENT_TARGET=$(MACOS_DEPLOYMENT_TARGET) cargo $(RUST_STABLE) rustc --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-darwin --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-darwin/release/$(LIB_NAME)"
	xcodebuild -create-xcframework \
	  -library "$(CLI_REPO)/target/aarch64-apple-darwin/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -output "$(FRAMEWORK_DIR)"
	@echo "Built $(FRAMEWORK_DIR) for macOS"

tvos: build-bindgen prepare
	TVOS_DEPLOYMENT_TARGET=$(TVOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-tvos --release --lib --crate-type staticlib
	TVOS_DEPLOYMENT_TARGET=$(TVOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-tvos-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-tvos/release/$(LIB_NAME)"
	xcodebuild -create-xcframework \
	  -library "$(CLI_REPO)/target/aarch64-apple-tvos/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -library "$(CLI_REPO)/target/aarch64-apple-tvos-sim/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -output "$(FRAMEWORK_DIR)"
	@echo "Built $(FRAMEWORK_DIR) for tvOS"

visionos: build-bindgen prepare
	XROS_DEPLOYMENT_TARGET=$(VISIONOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-visionos --release --lib --crate-type staticlib
	XROS_DEPLOYMENT_TARGET=$(VISIONOS_DEPLOYMENT_TARGET) cargo $(RUST_NIGHTLY) rustc -Z build-std --manifest-path "$(CARGO_MANIFEST)" --package smbcloud-auth-sdk-apple --target aarch64-apple-visionos-sim --release --lib --crate-type staticlib
	$(MAKE) generate-swift BINDGEN_INPUT="$(CLI_REPO)/target/aarch64-apple-visionos/release/$(LIB_NAME)"
	xcodebuild -create-xcframework \
	  -library "$(CLI_REPO)/target/aarch64-apple-visionos/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -library "$(CLI_REPO)/target/aarch64-apple-visionos-sim/release/$(LIB_NAME)" -headers "$(HEADERS_DIR)" \
	  -output "$(FRAMEWORK_DIR)"
	@echo "Built $(FRAMEWORK_DIR) for visionOS"

clean:
	rm -rf "$(FRAMEWORK_DIR)" "$(LOCAL_DIR)"
	@echo "Removed local SmbCloudAuth Swift build artifacts"
