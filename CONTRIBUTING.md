# Contributing to Return Launchpad

Thank you for your interest in contributing to Return Launchpad! This document provides guidelines and information for contributors.

## 🤝 Ways to Contribute

- **Bug Reports**: Help us identify and fix issues
- **Feature Requests**: Suggest new functionality
- **Code Contributions**: Submit improvements and new features
- **Documentation**: Improve README, code comments, and guides
- **Testing**: Test on different macOS versions and hardware
- **Translations**: Help localize the app (future feature)

## 🐛 Reporting Bugs

Before creating a bug report, please check if the issue already exists in [Issues](../../issues).

### Bug Report Template

```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
- macOS Version: [e.g. 15.5]
- App Version: [e.g. 1.0]
- Hardware: [e.g. MacBook Pro M1]

**Additional context**
Add any other context about the problem here.
```

## 💡 Suggesting Features

Feature requests are welcome! Please provide:

- **Clear description** of the feature
- **Use case** - why would this be useful?
- **Implementation ideas** - if you have thoughts on how it could work
- **Mockups or examples** - visual aids are helpful

## 🔧 Development Setup

### Prerequisites

- macOS 15.5 or later
- Xcode 16.4 or later
- Git

### Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/yourusername/return-launchpad.git
   cd return-launchpad
   ```
3. **Open** the project in Xcode:
   ```bash
   open "Return Launchpad.xcodeproj"
   ```
4. **Set up** your development team in project settings
5. **Build and run** to ensure everything works

### Project Structure

```
Return Launchpad/
├── Return_LaunchpadApp.swift    # App entry point and window configuration
├── ContentView.swift            # Main UI, grid layout, search functionality
├── AppManager.swift             # State management with ObservableObject
├── AppInfo.swift               # Data models and application scanning logic
└── Assets.xcassets/            # App icons and visual resources
```

## 📝 Coding Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Prefer `let` over `var` when possible
- Use proper access control (`private`, `internal`, `public`)

### SwiftUI Best Practices

- Use `@StateObject` for object creation, `@ObservedObject` for passing
- Prefer composition over inheritance
- Keep views small and focused
- Use proper state management patterns

### Code Organization

- Group related functionality together
- Use `// MARK:` comments for organization
- Add documentation comments for public APIs
- Keep functions focused and under 20 lines when possible

### Example Code Style

```swift
// MARK: - Grid Layout

/// Calculates the optimal number of items per page based on screen geometry
private func calculateItemsPerPage(geometry: GeometryProxy, totalApps: Int) -> Int {
    let searchAreaHeight: CGFloat = 95
    let navigationHeight: CGFloat = 80
    let gridPadding: CGFloat = 40
    
    // Calculate available space
    let availableHeight = geometry.size.height - searchAreaHeight - navigationHeight - gridPadding
    
    // ... rest of implementation
}
```

## 🧪 Testing

### Manual Testing

Before submitting a PR, please test:

- **Different screen sizes** (MacBook Air, iMac, external monitors)
- **Various app counts** (few apps, many apps, empty results)
- **Search functionality** (partial matches, no matches, special characters)
- **Pagination** (multiple pages, single page, page transitions)
- **Performance** (smooth animations, responsive UI)

### Automated Testing

- Run existing unit tests: `⌘U` in Xcode
- Add tests for new functionality
- Ensure all tests pass before submitting

## 📤 Submitting Changes

### Pull Request Process

1. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/awesome-feature
   ```

2. **Make your changes** following the coding guidelines

3. **Test thoroughly** on your development machine

4. **Commit your changes** with descriptive messages:
   ```bash
   git commit -m "Add awesome feature: brief description"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/awesome-feature
   ```

6. **Create a Pull Request** on GitHub

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on macOS 15.5+
- [ ] Tested with different screen sizes
- [ ] Tested search functionality
- [ ] Tested pagination
- [ ] All existing tests pass

## Screenshots
If applicable, add screenshots of the changes

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated if needed
```

## 🎯 Development Priorities

### High Priority
- Performance optimizations
- Accessibility improvements
- Bug fixes
- macOS compatibility

### Medium Priority
- New features from roadmap
- UI/UX enhancements
- Code refactoring

### Low Priority
- Code style improvements
- Documentation updates
- Minor feature additions

## 🤔 Questions?

- **General questions**: Use [GitHub Discussions](../../discussions)
- **Bug reports**: Create an [Issue](../../issues)
- **Feature ideas**: Create an [Issue](../../issues) with feature request label

## 📜 Code of Conduct

Please be respectful and professional in all interactions. We want Return Launchpad to be a welcoming project for contributors of all skill levels.

---

Thank you for contributing to Return Launchpad! 🚀