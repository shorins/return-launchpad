#!/bin/bash
# Builds a universal, sandboxed app. No Homebrew tools or Desktop modifications.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"
if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./create_release_dmg.sh
Requires Xcode 26.2+ with its command-line tools.
Optional environment:
  LAUNCHPAD_SIGN_IDENTITY  Developer ID Application identity (default: local ad-hoc)
  LAUNCHPAD_NOTARY_PROFILE Existing notarytool Keychain profile (only with Developer ID)
Outputs: build/releases/<timestamp>/ with .app, universal DMG and SHA256 checksum.
HELP
  exit 0
fi
for executable in xcodebuild codesign hdiutil ditto lipo; do
  command -v "$executable" >/dev/null || { echo "Missing tool: $executable" >&2; exit 1; }
done
build_dir="$repo_dir/build/ReleaseBuild"
release_dir="$repo_dir/build/releases/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$release_dir"
log_file="$release_dir/build.log"
echo "Building Release for Apple Silicon and Intel…"
if ! xcodebuild -project 'Return Launchpad.xcodeproj' -scheme 'Return Launchpad' \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$build_dir" -clonedSourcePackagesDirPath "$repo_dir/build/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build > "$log_file" 2>&1; then
  tail -60 "$log_file" >&2
  exit 1
fi
app_path="$release_dir/Return Launchpad.app"
ditto "$build_dir/Build/Products/Release/Return Launchpad.app" "$app_path"
lipo "$app_path/Contents/MacOS/Return Launchpad" -verify_arch arm64 x86_64
sign_identity="${LAUNCHPAD_SIGN_IDENTITY:--}"
sign_options=(--force --sign "$sign_identity" --options runtime --entitlements 'Return Launchpad/Return_Launchpad.entitlements')
if [[ "$sign_identity" == '-' ]]; then sign_options+=(--timestamp=none); else sign_options+=(--timestamp); fi
codesign "${sign_options[@]}" "$app_path"
codesign --verify --strict --verbose=2 "$app_path"
if [[ -n "${LAUNCHPAD_NOTARY_PROFILE:-}" ]]; then
  [[ "$sign_identity" != '-' ]] || { echo 'Notarization requires a Developer ID identity.' >&2; exit 1; }
  ditto -c -k --keepParent "$app_path" "$release_dir/Notarization.zip"
  xcrun notarytool submit "$release_dir/Notarization.zip" --keychain-profile "$LAUNCHPAD_NOTARY_PROFILE" --wait
  xcrun stapler staple "$app_path"
fi
stage="$(mktemp -d "$release_dir/stage.XXXXXX")"
trap 'if [[ -d "$stage" ]]; then rm -rf "$stage"; fi' EXIT
# The staging path is always a newly created child of this build's release directory.
ditto "$app_path" "$stage/Return Launchpad.app"
ln -s /Applications "$stage/Applications"
cp README.txt "$stage/README.txt"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
dmg_path="$release_dir/Return-Launchpad-$version-universal.dmg"
hdiutil create -volname 'Return Launchpad' -srcfolder "$stage" -format UDZO -fs HFS+ "$dmg_path"
hdiutil verify "$dmg_path"
if [[ -n "${LAUNCHPAD_NOTARY_PROFILE:-}" ]]; then
  codesign --sign "$sign_identity" --timestamp "$dmg_path"
  xcrun notarytool submit "$dmg_path" --keychain-profile "$LAUNCHPAD_NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg_path"
fi
(cd "$release_dir" && shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$dmg_path").sha256")
echo "App: $app_path"
echo "DMG: $dmg_path"
if [[ "$sign_identity" == '-' ]]; then
  echo 'Local ad-hoc build. Public Gatekeeper distribution requires Developer ID and notarization.'
fi
