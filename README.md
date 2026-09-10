<div align="center">

<img src="docs/images/banner.svg" alt="Return Launchpad — Apple retired the grid. We brought it back." width="100%">

**Your apps. Your folders. Your Mac.**

A native, full-screen app launcher for everyone who misses Launchpad.

[![Download](https://img.shields.io/github/v/release/shorins/return-launchpad?style=for-the-badge&label=Download&color=8b5cf6)](https://github.com/shorins/return-launchpad/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-15.5%2B-18181b?style=for-the-badge&logo=apple)](https://github.com/shorins/return-launchpad/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-18181b?style=for-the-badge)](LICENSE)

[Download for Mac](https://github.com/shorins/return-launchpad/releases/latest) · [Русский](README.ru.md) · [Report a bug](https://github.com/shorins/return-launchpad/issues/new/choose)

</div>

![Return Launchpad displaying a full page of applications](docs/images/launcher.jpg)

## The grid is back. And it’s yours.

Apple moved on from the classic Launchpad in macOS Tahoe. Some of us liked seeing our apps in one place. So we brought that experience back: a full-screen grid, folders you can arrange, and a shortcut that gets you there.

No account. No subscription. No analytics. Just a small, native Mac app that launches your other Mac apps.

## Made for the way you use your Mac

| | |
| --- | --- |
| **A shortcut away** | Open and hide with **⌃⌥Space**, or record your own shortcut. Enable launch at login if you want it always ready. |
| **Find it. Hit Return.** | Type a few letters, move through results with the arrow keys, and launch. An empty search turns the arrows into page controls. |
| **Make room for everything** | Discover installed apps and system utilities. Add extra application folders through Settings. |
| **Folders that feel like folders** | Drag to group, rename, reorder, or pull an app back out. Your actual app files stay exactly where they are. |
| **Motion with a purpose** | Sliding pages, folders that expand from their icons, and smooth drag previews. Choose smooth, springy or minimal motion. |
| **Your layout, remembered** | App order and folders survive restarts. **⌘Z** undoes a layout change. |

Native **SwiftUI + AppKit**. Universal **Apple Silicon + Intel** build. Respects macOS Reduce Motion and Reduce Transparency.

## A closer look

### Less hunting. More opening.

![Search results with keyboard selection](docs/images/search.jpg)

### Set it up once. Make it feel right.

<p align="center"><img src="docs/images/settings.jpg" alt="Settings for the shortcut, display, motion, icon size and launch at login" width="440"></p>

Screenshots show the real application. **The current app interface is in Russian**; app names retain their original language. English localization is a welcome contribution. The shortcut and login setting pictured above are customized, not the defaults.

## Install in a minute

1. [Download the latest release](https://github.com/shorins/return-launchpad/releases/latest) and choose **`Return-Launchpad-3.6.5-universal.dmg`** (or the newer version listed there).
2. Open the DMG and drag **Return Launchpad** into **Applications**.
3. Launch it and use **Control + Option + Space** to show or hide it.

**macOS 15.5 or newer · Apple Silicon and Intel · Free, MIT licensed**

> **First launch:** current downloads are ad-hoc signed and **not notarized by Apple**. macOS may block the first launch. If you trust this download, try opening it, then go to **System Settings → Privacy & Security → Open Anyway**. See [Apple’s instructions](https://support.apple.com/en-us/102445). No need to disable Gatekeeper system-wide.

Each release includes a `.sha256` file. Put it beside the DMG and run `shasum -a 256 -c Return-Launchpad-3.6.5-universal.dmg.sha256` to check the download. Updates are installed manually from Releases; quit the old app before replacing it.

## The essentials

| Action | How |
| --- | --- |
| Show / hide | **⌃⌥Space** — configurable in Settings |
| Search | Start typing; **arrows** select, **Return** launches |
| Change page | **Arrow keys** with an empty search |
| Create a folder | Hold an app over the center of another, then release after the highlight |
| Move across pages | Hold the dragged app near the left or right edge |
| Open a folder while dragging | Pause over the folder |
| Move out of a folder | Drag into the highlighted “main screen” area |
| Go back / dismiss | **Esc**, or click empty space; inside a folder, this returns to the grid first |
| Undo / redo layout | **⌘Z / ⇧⌘Z** |
| Settings / quit | **⌘, / ⌘Q** |

For apps in `~/Applications` or another custom directory, choose **Settings → Add application folder…** (shown as «Добавить папку приложений…»). Access is granted for that folder and remembered. Full Disk Access is not required.

## Small app. Open source.

The launcher keeps icons cached so the next page is ready. It stays available in the menu bar when hidden. In one short local audit with 206 apps, its background physical footprint was **33–44 MB**, with **0% CPU at idle samples**. These are measurements from one machine, not a universal guarantee; [the audit includes the method and limitations](docs/memory-audit.ru.md).

Want to build it, polish an animation, or help with localization? Start with the [development guide](docs/DEVELOPMENT.md) and [contributing guide](CONTRIBUTING.md).

[![Build](https://github.com/shorins/return-launchpad/actions/workflows/macos.yml/badge.svg)](https://github.com/shorins/return-launchpad/actions/workflows/macos.yml)

**Built with:** SwiftUI · AppKit · Core Animation · [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts). [Third-party notices](THIRD_PARTY_NOTICES.md).

If you missed Launchpad too, give the project a star. Let’s keep the grid around.

<details>
<summary>Star history</summary>

[![Star History Chart](https://api.star-history.com/svg?repos=shorins/return-launchpad&type=Date)](https://www.star-history.com/#shorins/return-launchpad&Date)

</details>

[MIT License](LICENSE). An independent community project, not affiliated with or endorsed by Apple. App icons in screenshots belong to their respective owners.
