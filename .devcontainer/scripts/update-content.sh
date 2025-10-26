#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

log() { echo "[update-content] $*"; }
warn() { echo "[update-content][warn] $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_WORKSPACE_ROOT="/workspaces"
if [[ ! -d "$DEFAULT_WORKSPACE_ROOT" ]]; then
  DEFAULT_WORKSPACE_ROOT="$(dirname "$ROOT_DIR")"
fi

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$DEFAULT_WORKSPACE_ROOT}"
WORKSPACE_STACK_NAME="${WORKSPACE_STACK_NAME:-${AIRNUB_WORKSPACE_NAME:-airnub-labs}}"
WORKSPACE_FILE_BASENAME="${WORKSPACE_CODE_WORKSPACE_BASENAME:-$WORKSPACE_STACK_NAME}"
WORKSPACE_FILE="${WORKSPACE_FILE:-$ROOT_DIR/${WORKSPACE_FILE_BASENAME}.code-workspace}"
STORE_DIR="${PNPM_STORE_PATH:-}"
PNPM_BIN="${PNPM_BIN:-pnpm}"

collect_workspace_paths() {
  if [[ ! -f "$WORKSPACE_FILE" ]]; then
    return 0
  fi

  python3 - "$WORKSPACE_FILE" "$ROOT_DIR" "$WORKSPACE_ROOT" <<'PY'
import json, os, sys
ws_path, root_dir, workspace_root = sys.argv[1:]
try:
    with open(ws_path, encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    sys.exit(0)
base_dir = os.path.dirname(ws_path)
seen = set()

def emit(path: str):
    path = os.path.normpath(path)
    if path not in seen:
        seen.add(path)
        print(path)

for folder in data.get("folders", []):
    rel = folder.get("path")
    if not rel:
        continue
    norm = os.path.normpath(os.path.join(base_dir, rel))
    emit(norm)
    leaf = os.path.basename(norm)
    if leaf and leaf not in (".", ".."):
        emit(os.path.normpath(os.path.join(workspace_root, leaf)))
PY
}

# Build a unique list of candidate directories to check for package.json files.
declare -a candidates=()
candidates+=("$ROOT_DIR")
if [[ "$WORKSPACE_ROOT" != "$ROOT_DIR" ]]; then
  candidates+=("$WORKSPACE_ROOT")
fi
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  candidates+=("$path")
done < <(collect_workspace_paths)

# Deduplicate the list while preserving order.
declare -A seen=()
declare -a unique_dirs=()
for dir in "${candidates[@]}"; do
  [[ -z "$dir" ]] && continue
  dir="${dir%/}"
  if [[ -z "${seen[$dir]:-}" ]]; then
    seen["$dir"]=1
    unique_dirs+=("$dir")
  fi
done

status=0
ran_any=0
for dir in "${unique_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    continue
  fi
  if [[ ! -f "$dir/package.json" ]]; then
    continue
  fi
  ran_any=1
  log "Running pnpm install in $dir"
  if [[ -n "$STORE_DIR" ]]; then
    if ! (cd "$dir" && "$PNPM_BIN" install --store-dir="$STORE_DIR"); then
      rc=$?
      warn "pnpm install failed in $dir"
      (( status == 0 )) && status=$rc
    fi
  else
    if ! (cd "$dir" && "$PNPM_BIN" install); then
      rc=$?
      warn "pnpm install failed in $dir"
      (( status == 0 )) && status=$rc
    fi
  fi
done

if (( ran_any == 0 )); then
  log "No package.json files found; skipping pnpm install."
fi

exit $status
