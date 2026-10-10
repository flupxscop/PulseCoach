#!/bin/zsh
# Runs the iPhone UI test suite on one simulator configuration and exports
# the step screenshots to .build/qa/<name>-named/.
#
# Usage: scripts/ui-regression.sh <name> <simulator-udid> <light|dark> [extra launch args]
# Example (small device, dark mode, large text):
#   scripts/ui-regression.sh se-dark-ax <udid> dark "-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL"
set -euo pipefail

cd "$(dirname "$0")/.."
name=$1; device=$2; appearance=$3; extra=${4:-}
out=.build/qa

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl ui "$device" appearance "$appearance"

mkdir -p "$out"
rm -rf "$out/$name.xcresult" "$out/$name" "$out/$name-named"

TEST_RUNNER_UI_EXTRA_ARGS="$extra" xcodebuild test \
  -project PulseCoach.xcodeproj -scheme PulseCoach \
  -destination "platform=iOS Simulator,id=$device" \
  -derivedDataPath .build/DerivedData \
  -resultBundlePath "$out/$name.xcresult" \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)" | tee "$out/$name.log" || true

xcrun xcresulttool export attachments --path "$out/$name.xcresult" --output-path "$out/$name" >/dev/null

python3 - "$out/$name" <<'PY'
import json, os, shutil, sys
src = sys.argv[1]
dst = src + "-named"
os.makedirs(dst, exist_ok=True)
for test in json.load(open(os.path.join(src, "manifest.json"))):
    for a in test.get("attachments", []):
        title = a.get("suggestedHumanReadableName", "")
        if title.endswith(".png"):
            shutil.copy(os.path.join(src, a["exportedFileName"]),
                        os.path.join(dst, title.split("_0_")[0] + ".png"))
print(f"Screenshots: {dst}")
PY
