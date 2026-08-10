SHELL := /bin/bash

APP_NAME := PasteDeck
VERSION ?= $(shell tr -d '[:space:]' < VERSION)
BUILD_NUMBER ?= 1
CONFIGURATION ?= release
ARCHS ?=

APP_BUNDLE := dist/$(APP_NAME).app
DMG_FILE := dist/$(APP_NAME)-$(VERSION).dmg
ZIP_FILE := dist/$(APP_NAME)-$(VERSION).zip

.PHONY: all build test app verify dmg archive dist run clean help version

all: app

build:
	CONFIGURATION="$(CONFIGURATION)" ARCHS="$(ARCHS)" ./script/package_app.sh

test:
	xcodebuild -project PasteDeck.xcodeproj -scheme PasteDeck -configuration Debug -destination "platform=macOS" -derivedDataPath .build/xcode-tests -clonedSourcePackagesDirPath .build/xcode-packages -skipPackageUpdates CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test

app:
	VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" CONFIGURATION="$(CONFIGURATION)" ARCHS="$(ARCHS)" ./script/package_app.sh

verify: app
	EXPECTED_VERSION="$(VERSION)" EXPECTED_ARCHS="$(ARCHS)" ./script/verify_app.sh "$(APP_BUNDLE)"

dmg: app
	VERSION="$(VERSION)" ./script/create_release_artifacts.sh dmg

archive: app
	VERSION="$(VERSION)" ./script/create_release_artifacts.sh zip

dist: verify
	VERSION="$(VERSION)" ./script/create_release_artifacts.sh all

run:
	./script/build_and_run.sh

version:
	@echo "$(VERSION)"

clean:
	rm -rf dist .build

help:
	@echo "PasteDeck build targets"
	@echo "  make test                         Run the Xcode test suite"
	@echo "  make app                          Build an ad-hoc signed .app"
	@echo "  make verify                       Validate bundle, resources, signature, and architectures"
	@echo "  make dist                         Build ZIP, DMG, and SHA-256 files"
	@echo "  make run                          Build and launch the app"
	@echo "  make clean                        Remove local build products"
	@echo ""
	@echo "Release example:"
	@echo "  VERSION=1.2.3 ARCHS='arm64 x86_64' make dist"
