<p align="center">
  <img src="Docs/Assets/pastedeck-banner.jpg" alt="PasteDeck project banner" width="100%">
</p>

<h1 align="center">PasteDeck</h1>

<p align="center">A fast, private, and open-source clipboard history manager for macOS</p>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <a href="https://github.com/jeffusion/PasteDeck/actions/workflows/ci.yml"><img src="https://github.com/jeffusion/PasteDeck/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/jeffusion/PasteDeck/releases/latest"><img src="https://img.shields.io/github/v/release/jeffusion/PasteDeck" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-111111" alt="macOS 13 or later">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/jeffusion/PasteDeck" alt="MIT License"></a>
</p>

PasteDeck is built with SwiftUI and AppKit. It helps you quickly recover recently copied text, images, and files, opens from a global keyboard shortcut, and keeps its data on your Mac without telemetry.

## Features

- Capture text, image, and file clipboard content
- Open the clipboard panel with `Command + Shift + V`
- Search, favorite, pin, and delete history items
- Switch between list and grid views
- Exclude apps whose clipboard content should not be recorded
- Store data locally with Core Data without usage-data uploads
- Use the app in Simplified Chinese, English, Japanese, or Russian

## Install

Download the latest build from [GitHub Releases](https://github.com/jeffusion/PasteDeck/releases/latest). Both the DMG and ZIP contain a universal app for Apple Silicon and Intel Macs.

To install from the DMG:

1. Download and open `PasteDeck-x.y.z.dmg`.
2. Drag `PasteDeck.app` into `Applications`.
3. Launch PasteDeck from the Applications folder.

> [!IMPORTANT]
> PasteDeck uses a fully open-source distribution process that requires no Apple developer account. The app is therefore not signed with Developer ID or notarized by Apple, and macOS will block it as an unidentified-developer app on first launch. After verifying the download source and SHA-256 checksum, open System Settings → Privacy & Security and choose Open Anyway. Do not disable Gatekeeper globally.

Verify a downloaded file:

```bash
shasum -a 256 -c PasteDeck-x.y.z.dmg.sha256
```

## Use

1. Launch PasteDeck and grant the permissions requested by macOS.
2. Copy text, an image, or a file as usual.
3. Press `Command + Shift + V` to open clipboard history.
4. Search for or select an item, or favorite, pin, or delete it.

## Privacy boundaries

- Clipboard history is stored in a Core Data database on the current Mac.
- PasteDeck contains no telemetry and does not upload clipboard content to a server.
- The current release does not support iCloud sync.
- The local database has no additional encryption. Anyone who can access the current macOS user's data may also be able to read it.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac
- Xcode 16 or later for source builds

## Build from source

```bash
git clone https://github.com/jeffusion/PasteDeck.git
cd PasteDeck
make test
make app
make run
```

Common commands:

| Command | Purpose |
| --- | --- |
| `make test` | Run the Xcode test suite |
| `make app` | Build and ad-hoc sign `dist/PasteDeck.app` |
| `make verify` | Validate app resources, architectures, and code signature |
| `make dist` | Generate ZIP, DMG, and SHA-256 files |
| `make run` | Build and run the app |
| `make clean` | Remove local build products |

You can also open `PasteDeck.xcodeproj` directly in Xcode. `project.yml` is the XcodeGen source configuration. After changing targets, dependencies, resources, or build settings, run `xcodegen generate` and commit the generated project files with it.

## Project structure

```text
PasteDeck/
|-- PasteDeck.xcodeproj/           Xcode macOS Application project
|-- project.yml                    XcodeGen source configuration
|-- Config/Info.plist              App bundle metadata
|-- Sources/PasteDeck/             Application source code
|-- Sources/Resources/             Localization resources
|-- Tests/PasteDeckTests/          Unit tests
|-- Resources/                     Application icon
|-- script/                        Build, packaging, and verification scripts
|-- .github/workflows/ci.yml       Continuous integration
`-- .github/workflows/release.yml  Automated releases
```

## Releases

Pushing a semantic version tag triggers GitHub Actions:

```bash
git tag v1.2.3
git push origin v1.2.3
```

The Release workflow runs the test suite, builds an `arm64 + x86_64` universal app, performs ad-hoc signing and structural validation, and publishes DMG, ZIP, and SHA-256 files. The entire process only uses the repository-provided `GITHUB_TOKEN` and requires no Apple credentials.

See the [distribution guide](Docs/Development/DISTRIBUTION.md) for details.

## Contributing

Issues and pull requests are welcome. Read the [contribution guide](CONTRIBUTING.md) before getting started.

## Roadmap

- iCloud sync
- Import and export
- Automatic updates
- Optional Developer ID signing and notarization

## License

PasteDeck is released under the [MIT License](LICENSE).
