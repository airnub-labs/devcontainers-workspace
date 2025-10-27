#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/usr/local/share/devcontainer/features/gui-tooling"

install -d "$TARGET_DIR/bin"
install -m 0755 "$SCRIPT_DIR/scripts/update-profiles.sh" "$TARGET_DIR/bin/update-profiles.sh"
