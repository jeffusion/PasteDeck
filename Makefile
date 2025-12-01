# PasteDeck Makefile
# Centralized build system for PasteDeck macOS app

# Configuration
APP_NAME := PasteDeck
BUNDLE_ID := com.pastedeck.app
# Allow VERSION to be overridden by environment variable (for CI/CD)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo "0.0.0")
BUILD_NUMBER := 1

# Directories
BUILD_DIR := .build
RELEASE_DIR := $(BUILD_DIR)/release
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SOURCE_RESOURCES := Resources

# Output files
EXECUTABLE := $(MACOS_DIR)/$(APP_NAME)
INFO_PLIST := $(CONTENTS_DIR)/Info.plist
PKG_INFO := $(CONTENTS_DIR)/PkgInfo
DMG_NAME := $(APP_NAME)-$(VERSION).dmg

# Tools
SWIFT := swift
CODESIGN := codesign
CREATE_DMG := create-dmg

# Build flags
SWIFT_BUILD_FLAGS := -c release

# Phony targets (not files)
.PHONY: all build release test clean distclean app sign dmg install uninstall run open version help

# Default target
all: app

# Help target
help:
	@echo "PasteDeck Build System"
	@echo "======================"
	@echo ""
	@echo "Targets:"
	@echo "  make app        - Build .app bundle (default)"
	@echo "  make dmg        - Build signed .app and create DMG"
	@echo "  make sign       - Sign .app bundle (ad-hoc)"
	@echo "  make test       - Run all tests"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make install    - Install to /Applications"
	@echo "  make uninstall  - Remove from /Applications"
	@echo "  make run        - Build and run the app"
	@echo "  make open       - Open .app in Finder"
	@echo "  make version    - Display current version"
	@echo "  make help       - Show this help"
	@echo ""
	@echo "Current version: $(VERSION)"

# Display version
version:
	@echo "$(VERSION)"

# Swift build targets
build:
	@echo "🔨 Building $(APP_NAME) (debug)..."
	$(SWIFT) build

release:
	@echo "🔨 Building $(APP_NAME) (release)..."
	$(SWIFT) build $(SWIFT_BUILD_FLAGS)

# Run tests
test:
	@echo "🧪 Running tests..."
	$(SWIFT) test

# Create .app bundle
app: release
	@echo "📦 Creating $(APP_NAME).app..."
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(MACOS_DIR)"
	@mkdir -p "$(RESOURCES_DIR)"
	@cp "$(RELEASE_DIR)/$(APP_NAME)" "$(MACOS_DIR)/"
	@echo "📝 Generating Info.plist..."
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>CFBundleDevelopmentRegion</key>' \
		'    <string>en</string>' \
		'    <key>CFBundleExecutable</key>' \
		'    <string>$(APP_NAME)</string>' \
		'    <key>CFBundleIconFile</key>' \
		'    <string>AppIcon</string>' \
		'    <key>CFBundleIdentifier</key>' \
		'    <string>$(BUNDLE_ID)</string>' \
		'    <key>CFBundleInfoDictionaryVersion</key>' \
		'    <string>6.0</string>' \
		'    <key>CFBundleName</key>' \
		'    <string>$(APP_NAME)</string>' \
		'    <key>CFBundlePackageType</key>' \
		'    <string>APPL</string>' \
		'    <key>CFBundleShortVersionString</key>' \
		'    <string>$(VERSION)</string>' \
		'    <key>CFBundleVersion</key>' \
		'    <string>$(BUILD_NUMBER)</string>' \
		'    <key>LSApplicationCategoryType</key>' \
		'    <string>public.app-category.productivity</string>' \
		'    <key>LSMinimumSystemVersion</key>' \
		'    <string>13.0</string>' \
		'    <key>LSUIElement</key>' \
		'    <true/>' \
		'    <key>NSHighResolutionCapable</key>' \
		'    <true/>' \
		'    <key>NSPrincipalClass</key>' \
		'    <string>NSApplication</string>' \
		'    <key>NSSupportsAutomaticTermination</key>' \
		'    <true/>' \
		'    <key>NSSupportsSuddenTermination</key>' \
		'    <false/>' \
		'</dict>' \
		'</plist>' \
		> "$(INFO_PLIST)"
	@echo -n "APPL????" > "$(PKG_INFO)"
	@if [ -f "$(SOURCE_RESOURCES)/AppIcon.icns" ]; then \
		cp "$(SOURCE_RESOURCES)/AppIcon.icns" "$(RESOURCES_DIR)/"; \
		echo "✅ App icon copied"; \
	else \
		echo "⚠️  No app icon found (app will use default icon)"; \
	fi
	@echo "✅ App bundle created at: $(APP_DIR)"

# Sign the app bundle (ad-hoc)
sign: app
	@echo "🔏 Signing $(APP_NAME).app (ad-hoc)..."
	@$(CODESIGN) --force --deep -s - "$(APP_DIR)" 2>&1 | grep -v "replacing existing signature" || true
	@echo "✅ App signed"

# Create DMG
dmg: sign
	@echo "📀 Creating DMG..."
	@if ! command -v $(CREATE_DMG) >/dev/null 2>&1; then \
		echo "❌ create-dmg not found!"; \
		echo ""; \
		echo "Install with: brew install create-dmg"; \
		echo ""; \
		exit 1; \
	fi
	@rm -f "$(DMG_NAME)"
	@DMG_OPTS="--volname $(APP_NAME) --window-pos 200 120 --window-size 660 400 --icon-size 100 --icon $(APP_NAME).app 160 185 --hide-extension $(APP_NAME).app --app-drop-link 500 185"; \
	if [ -f "$(SOURCE_RESOURCES)/dmg-background.png" ]; then \
		DMG_OPTS="$$DMG_OPTS --background $(SOURCE_RESOURCES)/dmg-background.png"; \
	fi; \
	if [ -f "$(SOURCE_RESOURCES)/AppIcon.icns" ]; then \
		DMG_OPTS="$$DMG_OPTS --volicon $(SOURCE_RESOURCES)/AppIcon.icns"; \
	fi; \
	$(CREATE_DMG) $$DMG_OPTS "$(DMG_NAME)" "$(APP_DIR)" 2>&1 | \
		grep -v "^Searching for dmg-license" | \
		grep -v "No such file or directory" || true
	@echo "✅ DMG created: $(DMG_NAME)"
	@shasum -a 256 "$(DMG_NAME)" > "$(DMG_NAME).sha256"
	@echo "✅ SHA256 checksum: $(DMG_NAME).sha256"

# Install to /Applications
install: app
	@echo "📥 Installing to /Applications..."
	@cp -r "$(APP_DIR)" /Applications/
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

# Uninstall from /Applications
uninstall:
	@echo "🗑️  Removing from /Applications..."
	@rm -rf "/Applications/$(APP_NAME).app"
	@echo "✅ Uninstalled"

# Build and run
run: app
	@echo "▶️  Running $(APP_NAME)..."
	@open "$(APP_DIR)"

# Open app in Finder
open: app
	@open "$(APP_DIR)"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf "$(APP_DIR)"
	@rm -f "$(DMG_NAME)" "$(DMG_NAME).sha256"
	@$(SWIFT) package clean
	@echo "✅ Clean complete"

# Complete clean (including SPM dependencies)
distclean: clean
	@echo "🧹 Deep cleaning..."
	@rm -rf .build .swiftpm
	@echo "✅ Deep clean complete"
