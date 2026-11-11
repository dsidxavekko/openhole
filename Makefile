# Local install first, then whatever `godot` is on PATH (e.g. Homebrew on macOS).
GODOT        ?= $(firstword $(wildcard $(HOME)/.local/opt/godot/godot) $(shell command -v godot 2>/dev/null) godot)
# First existing path wins: Linux layout in ~/.local/opt, then macOS (Homebrew, ~/.android).
ANDROID_HOME ?= $(firstword $(wildcard $(HOME)/.local/opt/android-sdk /opt/homebrew/share/android-commandlinetools $(HOME)/Library/Android/sdk) $(HOME)/.local/opt/android-sdk)
KEYSTORE     ?= $(firstword $(wildcard $(HOME)/.local/opt/debug.keystore $(HOME)/.android/debug.keystore) $(HOME)/.local/opt/debug.keystore)
ADB          ?= $(firstword $(wildcard $(ANDROID_HOME)/platform-tools/adb) adb)
PKG          := org.openhole.game
APK          := build/openhole.apk

# JDK 21: Linux package path or Homebrew openjdk@21; otherwise keep the environment's.
JAVA_HOME    ?= $(firstword $(wildcard /usr/lib/jvm/java-21-openjdk-amd64 /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home))
export ANDROID_HOME JAVA_HOME
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH     := $(KEYSTORE)
export GODOT_ANDROID_KEYSTORE_DEBUG_USER     := androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD := android

.PHONY: import test smoke apk release install run logcat run-pc web serve-web

import:
	$(GODOT) --headless --import --path . 2>&1 | grep -Ei "error|warn" || true

test: import
	timeout 180 $(GODOT) --headless --path . -s tests/run_tests.gd

# Runs a full bot-driven match without graphics, e.g. make smoke MODE=battle
MODE ?= classic
smoke: import
	timeout 400 $(GODOT) --headless --fixed-fps 60 --path . -- --autoplay --mode=$(MODE)

apk: import
	mkdir -p build
	$(GODOT) --headless --path . --export-debug "Android" $(APK)

# Release build signed with the owner's keystore. The preset has no release
# keystore of its own (that would put it in the repo), so export an unsigned
# APK, zipalign it and sign it with apksigner. Credentials live outside the
# repo in ~/.gradle/gradle.properties as gallium.keystore / gallium.key.alias /
# gallium.keystore.password / gallium.key.password.
RELEASE_APK  := build/openhole-release.apk
GRADLE_PROPS ?= $(HOME)/.gradle/gradle.properties
KEYSTORE_PATH := $(shell sed -n 's/^gallium\.keystore=//p' $(GRADLE_PROPS))
KEY_ALIAS     := $(shell sed -n 's/^gallium\.key\.alias=//p' $(GRADLE_PROPS))
STORE_PASS    := $(shell sed -n 's/^gallium\.keystore\.password=//p' $(GRADLE_PROPS))
KEY_PASS      := $(shell sed -n 's/^gallium\.key\.password=//p' $(GRADLE_PROPS))
# Newest build-tools available: SDK dir first, then the Homebrew macOS layout.
BUILD_TOOLS   ?= $(lastword $(sort $(wildcard $(ANDROID_HOME)/build-tools/*) $(wildcard /opt/homebrew/share/android-commandlinetools/build-tools/*)))

release: import
	@test -n "$(KEYSTORE_PATH)" || (echo "No release keystore in $(GRADLE_PROPS)" && exit 1)
	mkdir -p build
	# --export-release exits non-zero because the preset has no release keystore;
	# the unsigned APK it writes right before that is what we sign ourselves.
	-$(GODOT) --headless --path . --export-release "Android" build/openhole-release-unsigned.apk
	@echo "zipalign $(BUILD_TOOLS)"
	@$(BUILD_TOOLS)/zipalign -f -p 4 build/openhole-release-unsigned.apk build/openhole-release-aligned.apk
	@echo "apksigner sign with $(KEYSTORE_PATH) ($(KEY_ALIAS))"
	@$(BUILD_TOOLS)/apksigner sign --ks "$(KEYSTORE_PATH)" --ks-key-alias "$(KEY_ALIAS)" \
		--ks-pass "pass:$(STORE_PASS)" --key-pass "pass:$(KEY_PASS)" \
		--out $(RELEASE_APK) build/openhole-release-aligned.apk
	@$(BUILD_TOOLS)/apksigner verify --verbose $(RELEASE_APK)
	@echo "Release APK: $(RELEASE_APK)"

install:
	$(ADB) install -r $(APK)
	$(ADB) shell am start -n $(PKG)/com.godot.game.GodotAppLauncher || $(ADB) shell monkey -p $(PKG) 1

run: apk install

logcat:
	$(ADB) logcat -s godot:V

run-pc:
	$(GODOT) --path . --rendering-driver opengl3

# Browser build for itch.io (single-threaded, gl_compatibility renderer)
web: import
	mkdir -p out/web
	$(GODOT) --headless --path . --export-release "Web" out/web/index.html

# wasm does not load from file://, so serve it over HTTP
serve-web:
	python3 -m http.server 8000 --bind 127.0.0.1 --directory out/web
