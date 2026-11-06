#!/usr/bin/env bash
# One-command installer for Steel Panda.
#   curl -fsSL https://github.com/pandadad0214/Steel_Panda/releases/latest/download/install.sh | bash
# Downloads the latest Release package into ${STEEL_PANDA_HOME:-$HOME/steel-panda}.
# Works on Linux, macOS and Termux (Android). Needs bash, curl and tar.
# Unpacks files only. It does not run tasks.
set -euo pipefail
INSTALL_DIR="${INSTALL_DIR:-${STEEL_PANDA_HOME:-$HOME/steel-panda}}"
URL="https://github.com/pandadad0214/Steel_Panda/releases/latest/download/steel-panda.tar.gz"
mkdir -p "$INSTALL_DIR"
if [ -n "${PANDA_TARBALL:-}" ]; then
  tar xzf "$PANDA_TARBALL" -C "$INSTALL_DIR"
else
  curl -fsSL "$URL" | tar xz -C "$INSTALL_DIR"
fi
echo "Steel Panda installed in $INSTALL_DIR"
echo "Run it with: cd \"$INSTALL_DIR\" && bash steel.sh"
echo "Output is appended to steel.log next to steel.sh. A non-zero exit means a task failed or Steel could not start."
