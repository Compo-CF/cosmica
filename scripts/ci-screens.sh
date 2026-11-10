#!/usr/bin/env bash
# v4.0 — screenshot walk (CosmicaUITests on the -cosmicaDemo save), exported to ./shots
# as NN-screen.png. CI pushes ./shots to the `ci-screens` branch for the visual audit.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
SIM=$(xcrun simctl list devices available | grep -E "iPhone 1[6-9] Pro \(|iPhone 1[6-9] \(" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)
[ -n "$SIM" ] || SIM=$(xcrun simctl list devices available iPhone | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | tail -1)
echo "Using simulator $SIM: $(xcrun simctl list devices | grep "$SIM" | head -1)"
rm -rf screens.xcresult shots && mkdir -p shots
xcodebuild \
  -project Cosmica.xcodeproj \
  -scheme CosmicaScreens \
  -destination "id=$SIM" \
  -resultBundlePath screens.xcresult \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  test 2>&1 | tee screens.log | grep -E "error:|Test Case|TEST" || true
xcrun xcresulttool export attachments --path screens.xcresult --output-path shots-raw
python3 - <<'PY'
import json, os, shutil, re
raw, out = "shots-raw", "shots"
manifest = json.load(open(os.path.join(raw, "manifest.json")))
n = 0
for test in manifest:
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        name = re.sub(r"_\d+_[0-9A-F-]{36}", "", os.path.splitext(name)[0])
        shutil.copy(os.path.join(raw, a["exportedFileName"]), os.path.join(out, name + ".png"))
        n += 1
print(f"exported {n} screenshots")
PY
ls shots
