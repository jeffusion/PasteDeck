# PasteDeck - Xcode Project Setup Guide

This guide will help you create the Xcode project for PasteDeck.

## Quick Setup (Recommended)

### Step 1: Create Xcode Project

1. Open Xcode
2. Select **File → New → Project**
3. Choose **macOS → App**
4. Configure project:
   - **Product Name**: `PasteDeck`
   - **Team**: Select your Apple Developer team
   - **Organization Identifier**: `com.yourteam` (replace with your identifier)
   - **Bundle Identifier**: `com.yourteam.PasteDeck`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **Core Data** ✓ (check this box)
   - **Include Tests**: ✓ (check this box)

5. Save the project in this directory (replace the existing `PasteDeck/` folder)

### Step 2: Configure Project Settings

1. **General Tab**:
   - Minimum macOS version: **13.0** (Ventura)
   - Signing & Capabilities:
     - Enable **App Sandbox**
     - Enable **iCloud** → Check **CloudKit**
     - Create CloudKit container: `iCloud.com.yourteam.PasteDeck`
     - Enable **Keychain Sharing** (optional)

2. **Signing & Capabilities**:
   - Add capability: **App Sandbox**
   - Under App Sandbox, enable:
     - ✓ Outgoing Connections (Client)
     - ✓ User Selected Files (Read/Write) - for file clipboard items

3. **Info Tab**:
   - Add key `LSUIElement` = `YES` (to hide dock icon)
   - Add key `LSApplicationCategoryType` = `public.app-category.productivity`

### Step 3: Install Dependencies

We'll use Swift Package Manager for dependencies. In Xcode:

1. **File → Add Package Dependencies**
2. Add the following packages:

#### KeyboardShortcuts (by sindresorhus)
```
https://github.com/sindresorhus/KeyboardShortcuts
```
Version: Latest

#### LaunchAtLogin (by sindresorhus) - Optional
```
https://github.com/sindresorhus/LaunchAtLogin
```
Version: Latest

### Step 4: Configure Entitlements

Edit `PasteDeck.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Network (for iCloud) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- User Selected Files -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- iCloud -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourteam.PasteDeck</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>

    <!-- App Groups (for sync) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourteam.PasteDeck</string>
    </array>
</dict>
</plist>
```

### Step 5: Configure Info.plist

Add these keys to `Info.plist`:

```xml
<!-- Hide from Dock -->
<key>LSUIElement</key>
<true/>

<!-- App Category -->
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>

<!-- Human Interface Requirements -->
<key>NSHumanReadableDescription</key>
<string>A modern clipboard manager for macOS</string>

<!-- Accessibility Description (for global hotkeys) -->
<key>NSAccessibilityUsageDescription</key>
<string>PasteDeck needs accessibility access to enable global keyboard shortcuts for quick clipboard access.</string>
```

### Step 6: Organize Files

Move the generated source files into the proper directory structure:

```
PasteDeck/
├── App/
│   ├── PasteDeckApp.swift       (Move from root)
│   └── AppDelegate.swift        (Create new)
├── Models/
│   ├── ClipItem.swift           (Create new)
│   └── ClipContent.swift        (Create new)
├── Services/
│   ├── ClipboardMonitor.swift   (Create new)
│   └── ... (other services)
├── ViewModels/
│   └── ClipboardViewModel.swift (Create new)
├── Views/
│   ├── ContentView.swift        (Move from root)
│   └── ... (other views)
└── Resources/
    ├── Assets.xcassets          (Move from root)
    └── PasteDeck.xcdatamodeld   (Move from root - Core Data model)
```

In Xcode, use **File → Add Files** to add the pre-created source files from this repository.

### Step 7: Build Settings

1. **Build Settings → Swift Compiler - Language**:
   - Swift Language Version: **Swift 5**

2. **Build Settings → Deployment**:
   - macOS Deployment Target: **13.0**

3. **Build Settings → Architectures**:
   - Architectures: **Standard (Apple Silicon, Intel)**

### Step 8: Run Configuration

1. Edit scheme (Product → Scheme → Edit Scheme)
2. Run → Options:
   - ✓ Document Versions
   - ✓ Application Language: System Language

## Alternative: Import Existing Structure

If you prefer to keep the existing directory structure:

1. Create Xcode project as above but in a temporary location
2. Copy `.xcodeproj` file to this repository
3. Open the project and update file references to point to existing directories
4. In Project Navigator, remove and re-add file groups to match the structure

## Testing the Setup

1. Build the project (⌘B)
2. Run the app (⌘R)
3. Check that:
   - App launches successfully
   - Menu bar icon appears
   - Core Data stack initializes
   - No sandbox errors in console

## Troubleshooting

### "App is damaged and can't be opened"
- Go to System Settings → Privacy & Security → Allow
- Or disable Gatekeeper for development: `sudo spctl --master-disable`

### Sandbox Errors
- Check entitlements are properly configured
- Verify signing is enabled
- Check that container IDs match in entitlements and capabilities

### iCloud Not Working
- Ensure you're signed into iCloud in System Settings
- Verify CloudKit container is created in Developer Portal
- Check iCloud capability is enabled in project

### Global Hotkeys Not Working
- Grant Accessibility permission in System Settings → Privacy & Security → Accessibility
- Add Xcode to the allowed apps list

## Next Steps

Once the project is set up:
1. Verify the project builds successfully
2. Run the initial tests
3. Start implementing the ClipboardMonitor service
4. Follow the development roadmap in README.md

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Core Data Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [CloudKit Quick Start](https://developer.apple.com/documentation/cloudkit/creating_a_cloudkit_app)
- [App Sandbox Guide](https://developer.apple.com/documentation/security/app_sandbox)

## Support

If you encounter issues during setup:
- Check existing [GitHub Issues](https://github.com/yourusername/PasteDeck/issues)
- Create a new issue with setup logs
- Join our [Discussions](https://github.com/yourusername/PasteDeck/discussions)
