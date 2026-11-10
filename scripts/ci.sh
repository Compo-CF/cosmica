#!/usr/bin/env bash
# Simulator build + unit tests, no signing. Used by GitHub Actions (.github/workflows/ci.yml)
# and handy on the Mac. Adapted from Critter Conga's scripts/ci.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
SIM=$(xcrun simctl list devices available iPhone | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | tail -1)
echo "Using simulator $SIM"
xcodebuild -version
xcodebuild \
  -project Cosmica.xcodeproj \
  -scheme Cosmica \
  -destination "id=$SIM" \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  test 2>&1 | tee build.log | grep -E "error:|Test Suite .* (passed|failed)|Executed|BUILD|TEST|failed" || true
grep -q "TEST SUCCEEDED" build.log
