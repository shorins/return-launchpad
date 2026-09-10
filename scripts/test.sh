#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
selection=(-only-testing:'Return LaunchpadTests' test)
if [[ "${1:-}" == '--ui' ]]; then
  selection=(-skip-testing:'Return LaunchpadUITests/Return_LaunchpadUITestsLaunchTests/testLaunchPerformance' test)
elif [[ "${1:-}" == '--performance' ]]; then
  selection=(-only-testing:'Return LaunchpadUITests/Return_LaunchpadUITestsLaunchTests/testLaunchPerformance' test)
fi
mkdir -p build/TestResults
result_path="build/TestResults/$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project 'Return Launchpad.xcodeproj' -scheme 'Return Launchpad' \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/SignedTests -clonedSourcePackagesDirPath build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -resultBundlePath "$result_path" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= "${selection[@]}"
