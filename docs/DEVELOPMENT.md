# Development

Return Launchpad uses SwiftUI for the shell, AppKit for the grid and Core Animation for transitions. Requires macOS and Xcode 26.2+ / Swift 6.2+. The app runs on macOS 15.5+.

## Build

```sh
git clone https://github.com/shorins/return-launchpad.git
cd return-launchpad
xcodebuild -project 'Return Launchpad.xcodeproj' -scheme 'Return Launchpad' \
  -configuration Debug -derivedDataPath build/Development \
  -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Or open the project in Xcode and select the shared **Return Launchpad** scheme. The only third-party dependency is [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), pinned in `Package.resolved`. A network connection is needed to resolve it the first time.

## Test

```sh
./scripts/test.sh                # Unit and integration tests
./scripts/test.sh --ui           # Also UI tests; requires an active desktop
./scripts/test.sh --performance  # Optional launch benchmark
```

UI tests use an isolated fixture catalog and temporary layout. They never rearrange the user's apps. Do not interact with the desktop during UI tests. Results are saved in `build/TestResults`. Performance tests are deliberately outside the default suite.

## Package

```sh
./create_release_dmg.sh
```

Builds both arm64 and x86_64, verifies the architectures and signature, creates a DMG with an Applications shortcut, verifies the image and writes a portable SHA256 checksum. Outputs go to `build/releases/<timestamp>/`. Default builds are ad-hoc signed, sandboxed and **not notarized**.

For a notarized local build, install your Developer ID certificate and configure a notarytool Keychain profile, then run:

```sh
LAUNCHPAD_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
LAUNCHPAD_NOTARY_PROFILE='YOUR_EXISTING_KEYCHAIN_PROFILE' \
./create_release_dmg.sh
```

No signing credentials are stored in this repository. The hosted workflow currently publishes ad-hoc builds and does not perform notarization.

## Publish a release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project.
2. Add `docs/releases/vX.Y.Z.md` describing the final release and its signing status.
3. Merge to `main`, wait for CI, then push a matching tag:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

`.github/workflows/macos.yml` runs tests and packages a universal DMG on pull requests and pushes to main. A `v*` tag also verifies the tag matches the app version and publishes a GitHub Release with the DMG and checksum, only after successful tests and packaging. Release publication has its own job with `contents: write`; build jobs have read-only permissions. UI testing is opt-in through a manual run. Release jobs are not cancelled by another push. Published assets are not silently overwritten on reruns.

## Source map

| Component | Responsibility |
| --- | --- |
| `AppManager` | Catalog, search, navigation, layout transactions, undo/redo |
| `AppScanner` | Application discovery, including system directories |
| `LayoutDocument` / `LayoutPersistence` | Virtual folders, versioned JSON, migration, atomic writes |
| `LauncherGridView` | Reused AppKit tiles, internal drag handling, animated page layers |
| `IconCache` | Predecoded catalog icons and persistent PNG cache |
| `LauncherAppDelegate` | Overlay window, menu bar, keyboard shortcut, show/hide |
| `LauncherPreferences` / `SettingsView` | Motion, icon size, screen selection, launch at login |

Layout and catalog data live in Application Support inside the app container. Cached icons live in Caches. Folders are virtual: app bundles never move. The old layout is migrated with a backup; corrupt documents are not overwritten.

## Engineering notes

- [Implementation and validation (Russian)](implementation-and-validation.ru.md)
- [Motion research (Russian)](animation-research.ru.md)
- [Drag performance measurements (Russian)](drag-performance-3.5.ru.md)
- [Memory audit and its limitations (Russian)](memory-audit.ru.md)

Historical v1/v2 notes and old installer binaries are preserved in Git history; current installers live in GitHub Releases.
