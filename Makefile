# LocationChanger build & packaging.
#
# Common targets:
#   make build     — release build of both executables (universal2)
#   make app       — assemble build/LocationChanger.app
#   make sign      — codesign the app bundle (ad-hoc if DEVELOPER_ID unset)
#   make notarize  — submit to notary service (requires NOTARY_PROFILE env)
#   make verify    — lipo-info + codesign verification
#   make dmg       — build a distributable .dmg
#   make clean     — remove build artifacts
#   make test      — run the core test runner
#
# Env knobs:
#   DEVELOPER_ID        — Developer ID Application identity, e.g. "Developer ID Application: Name (TEAMID)"
#                         If unset, we sign ad-hoc with "-".
#   NOTARY_PROFILE      — notarytool keychain profile name
#   VERSION             — version string embedded in the .dmg filename (default: 1.0.0)

SHELL := /bin/bash
.ONESHELL:

SWIFT        ?= swift
CODESIGN     ?= /usr/bin/codesign
VERSION      ?= 1.0.0
DEVELOPER_ID ?= -
BUILD_DIR    := build
APP          := $(BUILD_DIR)/LocationChanger.app
SRC_RES      := Sources/LocationChangerApp/Resources
ENTITLEMENTS := $(SRC_RES)/LocationChanger.entitlements

# Universal2 build requires full Xcode's xcbuild (multi-arch swift build flag).
# Command Line Tools only supports native-arch builds; UNIVERSAL=1 opts in when
# Xcode is available.
UNIVERSAL ?= 0
ifeq ($(UNIVERSAL),1)
  ARCH_FLAGS := --arch arm64 --arch x86_64
  BIN_DIR    := .build/apple/Products/Release
else
  ARCH_FLAGS :=
  BIN_DIR    := .build/release
endif
BIN_APP := $(BIN_DIR)/LocationChangerApp
BIN_CLI := $(BIN_DIR)/locationchanger

.PHONY: all build test app icon sign verify notarize dmg clean

all: app verify

build:
	$(SWIFT) build -c release $(ARCH_FLAGS) --product LocationChangerApp
	$(SWIFT) build -c release $(ARCH_FLAGS) --product locationchanger

test:
	$(SWIFT) run LocationChangerTests

icon:
	mkdir -p $(BUILD_DIR)
	scripts/make-icon.swift $(BUILD_DIR)

app: build icon
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Helpers
	mkdir -p $(APP)/Contents/Resources
	mkdir -p $(APP)/Contents/Library/LaunchAgents

	# Executables
	cp $(BIN_APP) $(APP)/Contents/MacOS/LocationChangerApp
	cp $(BIN_CLI) $(APP)/Contents/Helpers/locationchanger
	chmod +x $(APP)/Contents/MacOS/LocationChangerApp
	chmod +x $(APP)/Contents/Helpers/locationchanger

	# Metadata
	cp $(SRC_RES)/Info.plist $(APP)/Contents/Info.plist
	cp $(BUILD_DIR)/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp $(SRC_RES)/com.locationchanger.agent.plist $(APP)/Contents/Library/LaunchAgents/com.locationchanger.agent.plist

	# PkgInfo helps the system recognise the bundle quickly.
	printf "APPL????" > $(APP)/Contents/PkgInfo

	@$(MAKE) sign

sign:
	@echo "==> Signing with: $(DEVELOPER_ID)"
	# Sign the helper first (inside-out).
	$(CODESIGN) --force --options=runtime --timestamp \
		--entitlements $(ENTITLEMENTS) \
		--sign "$(DEVELOPER_ID)" \
		$(APP)/Contents/Helpers/locationchanger
	# Then the main executable + bundle.
	$(CODESIGN) --force --options=runtime --timestamp \
		--entitlements $(ENTITLEMENTS) \
		--sign "$(DEVELOPER_ID)" \
		$(APP)/Contents/MacOS/LocationChangerApp
	$(CODESIGN) --force --options=runtime --timestamp \
		--entitlements $(ENTITLEMENTS) \
		--sign "$(DEVELOPER_ID)" \
		$(APP)

verify:
	@echo "==> lipo -info"
	-lipo -info $(APP)/Contents/MacOS/LocationChangerApp
	-lipo -info $(APP)/Contents/Helpers/locationchanger
	@echo "==> codesign --verify"
	$(CODESIGN) --verify --deep --strict --verbose=2 $(APP) || \
		echo "(ad-hoc signing: --strict may reject; run with a Developer ID for full verification)"
	@echo "==> spctl --assess (only passes with a Developer ID + notarisation)"
	-/usr/sbin/spctl --assess --type execute -vv $(APP)

notarize:
	@if [ -z "$(NOTARY_PROFILE)" ]; then \
		echo "NOTARY_PROFILE env var must be set"; exit 1; \
	fi
	mkdir -p $(BUILD_DIR)
	ditto -c -k --keepParent $(APP) $(BUILD_DIR)/LocationChanger.zip
	xcrun notarytool submit $(BUILD_DIR)/LocationChanger.zip \
		--keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(APP)

dmg: app
	rm -f $(BUILD_DIR)/LocationChanger-$(VERSION).dmg
	hdiutil create -volname "LocationChanger" \
		-srcfolder $(APP) \
		-ov -format UDZO \
		$(BUILD_DIR)/LocationChanger-$(VERSION).dmg
	@echo "==> $(BUILD_DIR)/LocationChanger-$(VERSION).dmg"

clean:
	rm -rf $(BUILD_DIR) .build
