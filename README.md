# PasteDeck

> A modern, open-source clipboard manager for macOS, inspired by Paste App

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 📋 Core Features (MVP)
- ✅ **Clipboard History**: Automatically captures all copied content (text, images, URLs, files)
- ✅ **Quick Access**: Global hotkey (`⌘⇧V`) for instant access
- ✅ **Smart Search**: Real-time search and filtering by content type
- ✅ **Favorites & Pins**: Save important items permanently
- ✅ **iCloud Sync**: Seamlessly sync across your Mac devices
- ✅ **Privacy First**: Excludes password managers and sensitive apps

### 🎨 User Experience
- Beautiful native macOS interface with Dark Mode support
- Floating window with keyboard navigation
- List and grid view options
- Visual previews for images and rich content

### 🔒 Security & Privacy
- Local encrypted storage
- Secure iCloud sync via CloudKit
- Customizable app exclusion list
- No telemetry or tracking

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- iCloud account (for sync features)

## Installation

### From Mac App Store
Coming soon!

### From Source
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/PasteDeck.git
   cd PasteDeck
   ```

2. Open the project in Xcode:
   ```bash
   open PasteDeck.xcodeproj
   ```

3. Build and run (⌘R)

## Development Setup

### Prerequisites
- Xcode 15.0+
- Swift 5.9+
- macOS 13.0+ development environment

### Project Structure
```
PasteDeck/
├── PasteDeck/
│   ├── App/                    # Application entry point
│   ├── Models/                 # Data models
│   ├── Services/               # Business logic services
│   │   ├── ClipboardMonitor.swift
│   │   ├── SyncManager.swift
│   │   └── StorageService.swift
│   ├── ViewModels/             # MVVM view models
│   ├── Views/                  # SwiftUI views
│   └── Resources/              # Assets and Core Data models
├── PasteDeckTests/
└── README.md
```

### Building the Project

1. **Using Xcode**: Open `PasteDeck.xcodeproj` and press ⌘R
2. **Command Line**:
   ```bash
   xcodebuild -project PasteDeck.xcodeproj -scheme PasteDeck -configuration Release build
   ```

### Setting Up iCloud

1. Configure your Apple Developer account in Xcode
2. Enable iCloud capability
3. Create an iCloud container: `iCloud.com.yourteam.PasteDeck`
4. Update the container ID in `PasteDeck.entitlements`

## Usage

### Default Keyboard Shortcuts
- `⌘⇧V` - Open PasteDeck window
- `↑/↓` - Navigate items
- `Enter` - Copy selected item
- `⌘Enter` - Copy and paste to active app
- `⌘F` - Focus search
- `⌘D` - Delete item
- `⌘S` - Toggle favorite
- `Esc` - Close window

### Configuration
Access preferences via menu bar icon → Preferences:
- Customize keyboard shortcuts
- Configure excluded applications
- Adjust history size (default: 200 items)
- Enable/disable iCloud sync
- Choose launch at login

## Architecture

PasteDeck follows Clean Architecture principles with MVVM pattern:

```
┌─────────────────────────────────────┐
│  Presentation Layer (SwiftUI)       │
│  - Views + ViewModels               │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Business Logic Layer               │
│  - ClipboardMonitor                 │
│  - SyncManager                      │
│  - SearchEngine                     │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Data Layer                         │
│  - Core Data                        │
│  - CloudKit                         │
│  - FileStorage                      │
└─────────────────────────────────────┘
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **AppKit**: System integration (NSPasteboard, NSStatusBar, NSPanel)
- **Combine**: Reactive programming for data flow
- **Core Data**: Local data persistence
- **CloudKit**: iCloud synchronization
- **KeyboardShortcuts**: Global hotkey management

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write meaningful commit messages
- Add tests for new features

## Roadmap

### Phase 1 (Current) - MVP
- [x] Project setup and architecture
- [ ] Clipboard monitoring
- [ ] Core Data setup
- [ ] Basic UI (list view)
- [ ] Global hotkey
- [ ] Search functionality

### Phase 2 - Core Features
- [ ] Image and file support
- [ ] Favorites and pins
- [ ] Menu bar integration
- [ ] Settings panel
- [ ] App exclusion list

### Phase 3 - iCloud Sync
- [ ] CloudKit integration
- [ ] Sync engine
- [ ] Conflict resolution
- [ ] Offline support

### Phase 4 - Polish & Release
- [ ] Performance optimization
- [ ] App sandboxing for Mac App Store
- [ ] Icon and branding
- [ ] User documentation
- [ ] Mac App Store submission

### Future Enhancements
- [ ] Smart snippets with variables
- [ ] Text transformations
- [ ] Collections/Pinboards
- [ ] iOS companion app
- [ ] Advanced search with regex
- [ ] Export/Import functionality

## Performance Targets

- Window response time: <100ms
- Clipboard capture delay: <50ms
- Search response: <200ms
- Memory usage: <50MB (idle)
- App startup time: <2s

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Paste App](https://pasteapp.io/)
- Icons by [SF Symbols](https://developer.apple.com/sf-symbols/)
- Built with love for the macOS community

## Contact & Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/PasteDeck/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/PasteDeck/discussions)
- **Twitter**: [@PasteDeckApp](https://twitter.com/PasteDeckApp)

---

Made with ❤️ by the PasteDeck community
