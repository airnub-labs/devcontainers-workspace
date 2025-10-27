#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/usr/local/share/devcontainer/features/supabase-stack"

install -d "$TARGET_DIR/bin"
install -m 0755 "$SCRIPT_DIR/scripts/bootstrap-supabase.sh" "$TARGET_DIR/bin/bootstrap-supabase.sh"
install -m 0755 "$SCRIPT_DIR/scripts/supabase-up.sh" "$TARGET_DIR/bin/supabase-up.sh"
