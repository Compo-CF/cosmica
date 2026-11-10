#!/usr/bin/env bash
# Simulator build + unit tests. Ad-hoc signed ("-"), not unsigned: the tests run inside the
# app, and an unsigned build has no iCloud entitlement, so CKContainer.default() throws
# "containerIdentifier can not be nil" at launch. Used by GitHub Actions (.github/workflows/ci.yml)
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
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  test 2>&1 | tee build.log | grep -E "error:|Test Suite .* (passed|failed)|Executed|BUILD|TEST|failed" || true
grep -q "TEST SUCCEEDED" build.log
