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

### Download DMG (Recommended)

1. **下载 DMG 文件**
   - 访问 [Releases 页面](https://github.com/yourusername/PasteDeck/releases)
   - 下载最新版本的 `PasteDeck-x.x.x.dmg`

2. **安装应用**
   - 双击打开下载的 DMG 文件
   - 将 PasteDeck 图标拖拽到 Applications 文件夹

3. **首次运行设置**（重要⚠️）

   在 macOS Sequoia 及更高版本中，首次运行未公证的应用需要以下步骤：

   a. 双击 Applications 文件夹中的 PasteDeck

   b. 系统会显示"无法打开"的警告对话框 - **这是正常的**

   c. 打开 **系统设置 → 隐私与安全性** (System Settings → Privacy & Security)

   d. 向下滚动到"安全性"(Security) 部分

   e. 找到关于 PasteDeck 的提示，点击 **"仍要打开"** (Open Anyway) 按钮

   f. 输入管理员密码进行授权

   g. 在弹出的确认对话框中点击"打开" (Open)

   h. 完成！后续打开 PasteDeck 不再需要这些步骤

4. **设置辅助功能权限**（可选，用于自动粘贴）

   首次使用自动粘贴功能时，应用会引导你授予辅助功能权限。

**为什么需要手动批准？**

PasteDeck 是开源软件，目前使用 ad-hoc 签名分发（无需付费的 Apple Developer Account $99/年）。macOS Gatekeeper 要求首次运行时手动批准非公证应用。这是一次性操作，完全安全。

### 从源代码构建

**系统要求**：
- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+ (可选，仅用于 Swift 工具链)

**构建步骤**：

1. 克隆仓库：
   ```bash
   git clone https://github.com/yourusername/PasteDeck.git
   cd PasteDeck
   ```

2. 构建可执行文件：
   ```bash
   swift build -c release
   ```

3. 创建 .app bundle：
   ```bash
   ./build.sh
   ```
   生成的应用位于 `.build/PasteDeck.app`

4. （可选）创建 DMG 分发包：
   ```bash
   # 安装依赖
   brew install create-dmg

   # 构建 DMG
   ./build-dmg.sh
   ```
   生成的 DMG 位于 `PasteDeck-1.0.0.dmg`

### Mac App Store
暂未上架（未来可能考虑）

## Development Setup

### Prerequisites
- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+ (可选，主要用于 Swift 工具链)
- Homebrew (用于安装 create-dmg)

### Project Structure
```
PasteDeck/
├── Sources/
│   └── PasteDeck/
│       ├── App/                    # Application entry point
│       │   └── AppDelegate.swift
│       ├── Models/                 # Data models
│       │   ├── ClipContent.swift
│       │   └── ClipItem.swift
│       ├── Services/               # Business logic services
│       │   ├── ClipboardMonitor.swift
│       │   ├── StorageService.swift
│       │   ├── SoundManager.swift
│       │   └── HotKeyManager.swift
│       ├── ViewModels/             # MVVM view models
│       │   └── ClipboardViewModel.swift
│       └── Views/                  # SwiftUI views
│           └── MainWindow.swift
├── Tests/
│   └── PasteDeckTests/
├── Resources/                      # App icon and DMG assets
├── build.sh                        # Build .app bundle
├── build-dmg.sh                    # Build DMG (calls build.sh)
├── Package.swift                   # Swift Package Manager manifest
└── README.md
```

### 构建项目

**使用 Swift Package Manager (推荐)**：

```bash
# 调试构建
swift build

# 发布构建
swift build -c release

# 运行测试
swift test

# 创建 .app bundle
./build.sh

# 创建 DMG 分发包
./build-dmg.sh
```

**使用 Xcode (可选)**：

```bash
# 生成 Xcode 项目
swift package generate-xcodeproj

# 使用 Xcode 打开
open PasteDeck.xcodeproj
```

### 首次设置

1. 克隆仓库并进入目录
2. 运行 `swift build` 确保依赖下载完成
3. 运行 `./build.sh` 创建应用
4. 测试运行：`open .build/PasteDeck.app`

### 发布新版本

1. 更新版本号（`build.sh` 和 `build-dmg.sh` 中的 `VERSION`）
2. 创建并推送 Git tag：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions 会自动构建并发布 DMG 到 Releases

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

### Phase 1 - MVP ✅
- [x] Project setup and architecture
- [x] Clipboard monitoring
- [x] Core Data setup
- [x] Basic UI (list view)
- [x] Global hotkey
- [x] Search functionality

### Phase 2 - Core Features ✅
- [x] Image and file preview UI
- [x] Favorites and pins
- [x] Menu bar integration
- [x] Settings panel
- [x] App exclusion list
- [x] Keyboard navigation in list
- [x] Copy and paste workflow

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
