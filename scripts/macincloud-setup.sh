#!/usr/bin/env bash
# One-time setup for a fresh MacInCloud session.
# Installs xcodegen as a standalone binary in ~/bin and persists PATH
# (Homebrew on the shared /opt/homebrew tree hits ownership/permission errors
# on MacInCloud Pay-As-You-Go boxes, so we skip brew entirely.)
#
# Safe to re-run — every step is idempotent.

set -euo pipefail

XCODEGEN_BIN="$HOME/bin/xcodegen"

if [ ! -x "$XCODEGEN_BIN" ]; then
  echo "Installing xcodegen to $XCODEGEN_BIN…"
  mkdir -p "$HOME/bin"
  curl -L -o /tmp/xcodegen.zip \
    https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
  unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen-extract
  cp /tmp/xcodegen-extract/xcodegen/bin/xcodegen "$XCODEGEN_BIN"
  chmod +x "$XCODEGEN_BIN"
else
  echo "xcodegen already installed at $XCODEGEN_BIN"
fi

# Persist PATH for future zsh sessions
if ! grep -q 'HOME/bin' "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
  echo "Added ~/bin to PATH in ~/.zshrc"
fi

# Also persist for bash (MacInCloud sometimes lands you in bash)
if ! grep -q 'HOME/bin' "$HOME/.bash_profile" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bash_profile"
  echo "Added ~/bin to PATH in ~/.bash_profile"
fi

export PATH="$HOME/bin:$PATH"

echo ""
echo "xcodegen: $(xcodegen --version)"
echo ""
echo "Next:"
echo "  xcodegen generate"
echo "  open Cosmica.xcodeproj"
