#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${DEVCONTAINER_LOG_DIR:-/var/log/devcontainer}"
LOG_FILE="${DEVCONTAINER_LOG_FILE:-$LOG_DIR/devcontainer.log}"
FOLLOW_TARGETS_RAW="${DEVCONTAINER_LOG_FOLLOW:-}"

mkdir -p "$LOG_DIR"
if [[ ! -e "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
fi

# Ensure the log file is writable by the current user (typically vscode)
chmod a+rw "$LOG_FILE" 2>/dev/null || true

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

initial_message="[$(timestamp)] Dev Container entrypoint ready (PID $$, user $(id -un)/$(id -u):$(id -g))."

# Emit the bootstrap message to STDOUT immediately so Docker logs (and Docker
# Desktop's stack view) pick it up even before we start tailing files. We also
# append it to the primary log file so the message is preserved for anyone who
# inspects the file later.
if [[ -n "$LOG_FILE" ]]; then
  printf '%s\n' "$initial_message" >>"$LOG_FILE"
fi
printf '%s\n' "$initial_message"

mapfile -t follow_targets < <(
  if [[ -n "$FOLLOW_TARGETS_RAW" ]]; then
    tr ':' '\n' <<<"$FOLLOW_TARGETS_RAW"
  fi
)

if [[ ${#follow_targets[@]} -eq 0 ]]; then
  follow_targets=("$LOG_FILE")
fi

for target in "${follow_targets[@]}"; do
  if [[ -n "$target" ]]; then
    mkdir -p "$(dirname "$target")" 2>/dev/null || true
    touch "$target" 2>/dev/null || true
    chmod a+rw "$target" 2>/dev/null || true
  fi
done

# Tail all targets (starting from the end of each file so we do not duplicate
# the initial bootstrap message emitted above) and keep the container alive.
exec tail -n 0 -F "${follow_targets[@]}"
