# Contributing to PasteDeck

First off, thank you for considering contributing to PasteDeck! It's people like you that make PasteDeck such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Describe the behavior you observed and what you expected**
- **Include screenshots if possible**
- **Include your environment details**:
  - macOS version
  - PasteDeck version
  - Any relevant system settings

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List some examples of how it would be used**

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our coding standards
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Write a clear commit message**
6. **Submit a pull request**

#### Pull Request Guidelines

- Keep pull requests focused on a single feature or bug fix
- Write clear, concise commit messages
- Include tests for new features
- Update documentation as needed
- Ensure all tests pass
- Follow the existing code style

## Development Setup

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- An Apple Developer account (for signing and testing)

### Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/PasteDeck.git
   cd PasteDeck
   ```

2. **Follow the setup guide** in `SETUP.md`

3. **Build and run**:
   - Open `PasteDeck.xcodeproj` in Xcode
   - Select the PasteDeck scheme
   - Press ⌘R to build and run

### Project Structure

```
PasteDeck/
├── App/                    # Application entry point
├── Models/                 # Data models
├── Services/               # Business logic
├── ViewModels/             # MVVM view models
├── Views/                  # SwiftUI views
├── Utilities/              # Helper utilities
└── Resources/              # Assets and Core Data
```

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and [Google's Swift Style Guide](https://google.github.io/swift/).

#### Key Points

- Use descriptive names for types, properties, and methods
- Prefer `let` over `var` when possible
- Use type inference where appropriate
- Organize code with `// MARK:` comments
- Keep functions focused and concise
- Document public APIs with comments

#### Example

```swift
// MARK: - Properties

/// The maximum number of items to store in history
private let maxHistorySize: Int

// MARK: - Public Methods

/// Adds a new clipboard item to the history
/// - Parameter item: The clipboard item to add
func addItem(_ item: ClipItem) {
    // Implementation
}

// MARK: - Private Methods

private func saveItems() {
    // Implementation
}
```

### SwiftUI Guidelines

- Keep views small and focused
- Extract reusable components
- Use `@State`, `@Binding`, `@ObservedObject` appropriately
- Prefer composition over large view hierarchies
- Use `// MARK:` to organize view code

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(clipboard): add support for color clipboard items

fix(ui): prevent window from closing on Escape key

docs(readme): update installation instructions
```

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -project PasteDeck.xcodeproj -scheme PasteDeck

# Run specific test
xcodebuild test -project PasteDeck.xcodeproj -scheme PasteDeck -only-testing:PasteDeckTests/ClipboardMonitorTests
```

### Writing Tests

- Write unit tests for business logic
- Write UI tests for critical user flows
- Use descriptive test names: `testClipboardMonitorCapturesText()`
- Keep tests focused and independent
- Mock dependencies where appropriate

Example:

```swift
class ClipboardMonitorTests: XCTestCase {
    var monitor: ClipboardMonitor!

    override func setUp() {
        super.setUp()
        monitor = ClipboardMonitor()
    }

    override func tearDown() {
        monitor.stopMonitoring()
        monitor = nil
        super.tearDown()
    }

    func testStartMonitoringSetsIsMonitoringTrue() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
    }
}
```

## Documentation

### Code Documentation

- Document public APIs using Swift documentation comments
- Include parameter descriptions
- Provide usage examples for complex APIs

```swift
/// Monitors the system clipboard and publishes changes
///
/// This class continuously monitors the macOS clipboard (NSPasteboard)
/// and publishes new items through a Combine publisher.
///
/// Example:
/// ```swift
/// let monitor = ClipboardMonitor()
/// monitor.startMonitoring()
/// monitor.clipboardItemPublisher
///     .sink { item in
///         print("New clipboard item: \(item)")
///     }
/// ```
class ClipboardMonitor: ObservableObject {
    // ...
}
```

### README and Guides

- Keep documentation up to date with code changes
- Use clear, concise language
- Include code examples where helpful
- Add screenshots for visual features

## Architecture Guidelines

### MVVM Pattern

- **Models**: Pure data structures, no business logic
- **ViewModels**: Business logic, data transformation
- **Views**: UI only, minimal logic

### Dependency Injection

- Inject dependencies through initializers
- Use protocols for testability
- Avoid singletons when possible

### Combine Framework

- Use publishers for asynchronous events
- Clean up subscriptions properly
- Prefer `@Published` for simple state

## Performance Considerations

- Profile before optimizing
- Use lazy loading for large datasets
- Implement virtual scrolling for long lists
- Compress images appropriately
- Monitor memory usage

## Security Best Practices

- Never commit sensitive data (API keys, passwords)
- Validate all user input
- Use secure coding practices
- Respect user privacy
- Handle clipboard data securely

## Accessibility

- Support keyboard navigation
- Provide meaningful accessibility labels
- Test with VoiceOver
- Support Dynamic Type
- Follow Apple's accessibility guidelines

## Release Process

1. Update version number in Xcode project
2. Update CHANGELOG.md
3. Create a release branch
4. Run all tests
5. Build release version
6. Create GitHub release with release notes
7. Submit to Mac App Store (if applicable)

## Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Email**: For security issues or private matters

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- About section of the app

## License

By contributing to PasteDeck, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to PasteDeck! 🎉
