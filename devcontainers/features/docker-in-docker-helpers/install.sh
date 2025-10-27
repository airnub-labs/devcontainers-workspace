#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/usr/local/share/devcontainer/features/docker-in-docker-helpers"

install -d "$TARGET_DIR/bin"
install -m 0755 "$SCRIPT_DIR/scripts/post-start.sh" "$TARGET_DIR/bin/post-start.sh"
