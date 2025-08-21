# Return Launchpad

A modern, open-source application launcher for macOS that brings back the classic Launchpad functionality removed in macOS Sequoia (Tahoe). Built with SwiftUI for macOS 15.5+.

## 🎯 Purpose

Apple removed the traditional Launchpad from macOS Sequoia, leaving users without a familiar way to browse and launch their applications in a grid view. Return Launchpad restores this functionality with modern enhancements and improvements.

## ✨ Features

- **Full-Screen Grid View**: Clean, organized display of all your applications
- **Smart Search**: Real-time filtering as you type
- **Responsive Layout**: Automatically adapts to different screen sizes
- **Pagination**: Navigate through multiple pages of applications
- **Hover Effects**: Smooth animations and visual feedback
- **Centered Results**: Filtered search results are perfectly centered
- **One-Click Launch**: Click any app to launch it instantly
- **Auto-Close**: Launcher closes automatically after launching an app
- **Floating Window**: Appears above all other windows
- **Blur Background**: Native macOS visual effects for a polished look

## 🖼️ Screenshots

*Coming soon - Screenshots will be added to showcase the interface*

## 🔧 Requirements

- macOS 15.5 (Sequoia) or later
- Xcode 16.4+ (for building from source)
- Apple Developer account (for code signing)

## 🚀 Installation

### Option 1: Download Pre-built Binary (Recommended)

1. Go to the [Releases](../../releases) page
2. Download the latest `Return Launchpad.app`
3. Move the app to your `/Applications` folder
4. Right-click the app and select "Open" to bypass Gatekeeper on first launch

### Option 2: Build from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/return-launchpad.git
   cd return-launchpad
   ```

2. Open the project in Xcode:
   ```bash
   open "Return Launchpad.xcodeproj"
   ```

3. Select your development team in the project settings
4. Build and run the project (⌘R)

## 📖 Usage

### Launching the App
- Open Return Launchpad from your Applications folder
- The launcher will appear as a full-screen overlay
- All your applications will be displayed in a grid

### Navigation
- **Search**: Start typing to filter applications by name
- **Browse**: Scroll through pages using the navigation arrows at the bottom
- **Launch**: Click any app icon to launch the application
- **Close**: Click anywhere on the background or press Escape

### Keyboard Shortcuts
- **Search**: Just start typing when the launcher is open
- **Escape**: Close the launcher
- **Arrow Keys**: Navigate between pages (when available)

## 🏗️ Architecture

Return Launchpad is built with modern Swift and SwiftUI practices:

- **SwiftUI Framework**: Native macOS UI with smooth animations
- **ObservableObject Pattern**: Reactive state management
- **Modular Design**: Clean separation of concerns
- **App Scanning**: Automatic discovery of installed applications
- **Icon Extraction**: Native app icon retrieval and display

### Project Structure

```
Return Launchpad/
├── Return_LaunchpadApp.swift    # App entry point
├── ContentView.swift            # Main UI and layout logic
├── AppManager.swift             # State management
├── AppInfo.swift               # Data models and app scanning
└── Assets.xcassets/            # App icons and resources
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Follow Swift and SwiftUI best practices
- Maintain compatibility with macOS 15.5+
- Add comments for complex logic
- Test on different screen sizes
- Ensure accessibility compliance

## 🐛 Bug Reports & Feature Requests

Please use the [Issues](../../issues) page to:
- Report bugs with detailed reproduction steps
- Request new features with clear use cases
- Ask questions about usage or development

## 📋 Roadmap

- [ ] **v1.1**: Custom app categories and folders
- [ ] **v1.2**: Keyboard-only navigation
- [ ] **v1.3**: Custom themes and appearance options
- [ ] **v1.4**: App usage statistics and sorting
- [ ] **v1.5**: Integration with Spotlight search

## 🔒 Privacy

Return Launchpad respects your privacy:
- **No Data Collection**: The app doesn't collect or transmit any personal data
- **Local Operation**: All app scanning and indexing happens locally
- **No Network Access**: The app doesn't require internet connectivity
- **Sandboxed**: Runs in Apple's security sandbox for your protection

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple for the original Launchpad design inspiration
- The Swift and SwiftUI community for excellent documentation and examples
- All contributors who help improve this project

## 💬 Support

- **Documentation**: Check this README and the project wiki
- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Join GitHub Discussions for general questions and ideas

---

**Made with ❤️ for the macOS community**

*Bring back the Launchpad experience you know and love!*