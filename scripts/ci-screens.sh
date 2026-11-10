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
CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -i cosmica | head -1 || true)
if [ -n "$CRASH" ]; then
  echo "===== crash report: $CRASH ====="
  python3 - ~/Library/Logs/DiagnosticReports/"$CRASH" <<'PY' | tee crash.txt
import json, sys
text = open(sys.argv[1]).read()
body = json.loads(text[text.index("\n") + 1:])
print("exception:", body.get("exception"), "| termination:", body.get("termination", {}).get("indicator"))
ft = body.get("faultingThread", 0)
images = body.get("usedImages", [])
for f in body["threads"][ft]["frames"][:25]:
    img = images[f["imageIndex"]].get("name", "?") if f.get("imageIndex") is not None else "?"
    print(f"  {img:28s} {f.get('symbol', '?')}  {f.get('sourceFile', '')}:{f.get('sourceLine', '')}")
PY
fi
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
