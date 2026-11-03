# Local install first, then whatever `godot` is on PATH (e.g. Homebrew on macOS).
GODOT        ?= $(firstword $(wildcard $(HOME)/.local/opt/godot/godot) $(shell command -v godot 2>/dev/null) godot)
ANDROID_HOME ?= $(HOME)/.local/opt/android-sdk
KEYSTORE     ?= $(HOME)/.local/opt/debug.keystore
PKG          := org.openhole.game
APK          := build/openhole.apk

# Only force JAVA_HOME when the Linux default exists; elsewhere keep the environment's.
ifneq ($(wildcard /usr/lib/jvm/java-21-openjdk-amd64),)
JAVA_HOME    ?= /usr/lib/jvm/java-21-openjdk-amd64
endif
export ANDROID_HOME JAVA_HOME
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH     := $(KEYSTORE)
export GODOT_ANDROID_KEYSTORE_DEBUG_USER     := androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD := android

.PHONY: import test smoke apk install run logcat run-pc web serve-web

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

install:
	adb install -r $(APK)
	adb shell am start -n $(PKG)/com.godot.game.GodotAppLauncher || adb shell monkey -p $(PKG) 1

run: apk install

logcat:
	adb logcat -s godot:V

run-pc:
	$(GODOT) --path . --rendering-driver opengl3

# Browser build for itch.io (single-threaded, gl_compatibility renderer)
web: import
	mkdir -p out/web
	$(GODOT) --headless --path . --export-release "Web" out/web/index.html

# wasm does not load from file://, so serve it over HTTP
serve-web:
	python3 -m http.server 8000 --bind 127.0.0.1 --directory out/web
