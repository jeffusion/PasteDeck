# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
swift build                    # Debug build
swift build -c release        # Release build
swift build --clean           # Clean build

# Testing
swift test                              # Run all tests
swift test --filter ClipboardMonitorTests  # Specific test suite
swift test -v                           # Verbose output

# Create .app bundle
./build.sh                     # Generates unsigned .build/PasteDeck.app
```

## Architecture Overview

PasteDeck is a macOS clipboard manager using **MVVM architecture** with clean separation:

```
Views (SwiftUI) → ViewModels → Services → Data Layer (Core Data)
```

### Key Components

**ClipboardMonitor** (`Services/ClipboardMonitor.swift`)
- Timer-based polling (0.5s interval) of NSPasteboard.changeCount
- Publishes clipboard changes via Combine PassthroughSubject
- Has app exclusion list for password managers/security apps

**ClipboardViewModel** (`ViewModels/ClipboardViewModel.swift`)
- Central MVVM coordinator with @Published state
- Handles search (300ms debounce), filtering, sorting
- Implements duplicate detection (same content → move to top, not duplicate)
- Max history enforcement (default 200, pinned/favorites exempt)

**StorageService** (`Services/StorageService.swift`)
- Core Data CRUD operations
- Background context for writes, main context for reads
- Publishes itemsChangedPublisher for reactive updates

**AppDelegate** (`App/AppDelegate.swift`)
- **Critical**: Calls `registerDefaultSettings()` FIRST in applicationDidFinishLaunching
- Menu bar app (NSStatusBar) + floating drawer (NSPanel)
- Manages global event monitors and keyboard shortcuts

### Data Model Flow

```
NSPasteboard → ClipContent (enum) → ClipItem (struct) → ClipItemEntity (Core Data)
```

**ClipContent** (`Models/ClipContent.swift`): 6 content types (text, image, url, file, multipleFiles, color)
- `from(pasteboard:)` extracts content with priority: Color → Image → Files → URL → RTF → Text
- `write(to:)` writes back to pasteboard

**ClipItem** (`Models/ClipItem.swift`): Main model with metadata (sourceApp, tags, stats, etc.)
- Sorting: Pinned → Favorites → Most Recent
- Has search matching, filtering extensions

## Configuration Management

**Standard Pattern**: Uses `UserDefaults.register(defaults:)` in `AppDelegate.registerDefaultSettings()`

All settings registered centrally:
- `launchAtLogin`: false
- `iCloudSyncEnabled`: true
- `showInMenuBar`: true (menu bar icon visible by default)
- `soundEnabled`: true
- `pasteMode`: "activeApp"
- `alwaysPastePlainText`: false
- `historyRetentionDays`: 30

**UI Layer**: Uses `@AppStorage` property wrappers in SettingsView.swift
**Service Layer**: Uses `UserDefaults.standard.bool(forKey:)` directly (relies on registered defaults)

## Window Architecture (Menu Bar App)

- **Activation Policy**: `.accessory` (no dock icon)
- **Status Bar**: NSStatusItem with clipboard icon, toggle on click
- **Main Window**: Floating NSPanel (borderless, non-activating)
- **Drawer Behavior**: Slides from bottom (0.15s show, 0.12s hide)
- **Focus Management**: Window level lowered before paste to allow CGEvent keyboard simulation

## Paste Automation Flow

```
User selects item → copyAndPaste() → onPrepareForPaste (lower window) →
CGEvent Cmd+V (10ms delay) → hideClipboardWindow()
```

Requires accessibility permission. Fallback: content copied to clipboard for manual paste.

## Important Implementation Details

**Duplicate Detection**: Compares actual content, not IDs. Existing duplicate moves to index 0, useCount++

**Max History Enforcement**: Called when adding new item AND on explicit save. Pinned/favorites never removed.

**Clipboard Capture**: Excludes apps by default (1Password, LastPass, Keychain Access, etc.). Configurable in PrivacySettingsView.

**Global Shortcuts**: Uses KeyboardShortcuts package (sindresorhus). Default: Cmd+Shift+V. Requires accessibility permission.

**Launch at Login**: Uses SMAppService.mainApp (macOS 13+). Service: `LaunchAtLoginService.shared.sync(with:)`

## Adding New Features

**New Content Type**:
1. Add case to `ClipContent` enum
2. Implement `from(pasteboard:)` extraction logic
3. Implement `write(to:)` write-back logic
4. Add display properties: `typeName`, `previewString`, `iconName`
5. Update Codable encode/decode

**New Filter**:
1. Add case to `ClipItem.ContentFilter` or create new filter enum
2. Implement `matches(_:)` method in ClipItem
3. Add `@Published` property to ClipboardViewModel
4. Add UI control in MainWindow/SettingsView
5. Update `applyFilters()` in ViewModel

**New Service**:
1. Create in `Services/` directory
2. Use `@MainActor` if touches UI
3. Follow singleton pattern if stateful (`static let shared`)
4. Inject via constructor in ViewModel
5. Add initialization in AppDelegate.applicationDidFinishLaunching

## Testing Conventions

- Location: `Tests/PasteDeckTests/`
- Use `@MainActor` for UI-related test classes
- Mock services by injecting test doubles
- Preview mode: `PersistenceController.preview` has sample data

## Common Pitfalls

❌ **Don't** use defensive nil-checks for UserDefaults keys with registered defaults
✅ **Do** rely on `registerDefaultSettings()` being called first

❌ **Don't** call `UserDefaults.standard.set()` in multiple places
✅ **Do** use @AppStorage in UI, rely on registered defaults elsewhere

❌ **Don't** modify ClipItemEntity directly in views
✅ **Do** go through ClipboardViewModel methods

❌ **Don't** perform Core Data operations on main thread
✅ **Do** use StorageService which handles context management

## Project Metadata

- **Language**: Swift 5.9+
- **Platform**: macOS 13.0+ (Ventura)
- **UI Framework**: SwiftUI + AppKit (hybrid)
- **Persistence**: Core Data (programmatic model, no .xcdatamodeld)
- **Dependencies**: KeyboardShortcuts (SPM)
- **Package Manager**: Swift Package Manager
