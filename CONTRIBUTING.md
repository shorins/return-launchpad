# Contributing

Help keep the grid around. Bug reports, small fixes, accessibility improvements and localization are welcome. English and Russian are both fine.

## Report an issue

Use the [issue forms](https://github.com/shorins/return-launchpad/issues/new/choose). Include the app version, macOS version, Apple Silicon or Intel, steps to reproduce, and what you expected. A short recording helps with motion and drag problems. Remove private information from screenshots and logs.

## Change the code

1. Fork the repository and create a focused branch.
2. Follow the [development guide](docs/DEVELOPMENT.md) to build and test.
3. Keep changes scoped to one problem. Preserve existing layouts and settings.
4. Explain the behavior before and after, and how you checked it. Include a screenshot for visual changes.
5. Open a pull request. Never include signing certificates, tokens, local user data or built DMGs.

Use native macOS APIs where they fit. Honor Reduce Motion, keyboard navigation and accessibility labels. Performance claims should include a reproducible measurement; tests should cover behavior rather than implementation details.

Unit tests run in CI. Desktop UI tests are opt-in. The app interface currently uses Russian strings; an English localization contribution should use localization resources consistently rather than replace existing Russian text.

## License

By contributing, you agree that your contribution is provided under the repository’s MIT license. Preserve third-party license notices.
