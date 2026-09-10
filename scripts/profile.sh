#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
app_path="${1:-$repo_dir/build/SignedTests/Build/Products/Debug/Return Launchpad.app}"
[[ -d "$app_path" ]] || { echo 'Build with ./scripts/test.sh first, or pass an app path.' >&2; exit 1; }
mkdir -p build/Profiles
trace_path="$repo_dir/build/Profiles/launch-$(date +%Y%m%d-%H%M%S).trace"
# Launch the exact binary, then attach by PID: Launch Services may otherwise
# choose an installed app with the same bundle identifier.
"$app_path/Contents/MacOS/Return Launchpad" --ui-testing &
profile_pid=$!
trap 'kill -TERM "$profile_pid" 2>/dev/null || true' EXIT
record_status=0
xcrun xctrace record --template 'Time Profiler' --time-limit 15s --output "$trace_path" \
  --attach "$profile_pid" || record_status=$?
# Instruments can return a nonzero status after killing its launched target at the
# time limit. Validate the saved recording and its end reason before accepting it.
toc_path="${trace_path%.trace}-toc.xml"
xcrun xctrace export --input "$trace_path" --toc --output "$toc_path"
if [[ "$record_status" -ne 0 ]] && ! /usr/bin/grep -q '<end-reason>Time limit reached</end-reason>' "$toc_path"; then
  echo "Recording failed (status $record_status); inspect $toc_path" >&2
  exit "$record_status"
fi
printf 'Trace: %s\n' "$trace_path"
