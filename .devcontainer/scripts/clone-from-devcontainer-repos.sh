#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

log() { echo "[clone] $*"; }
warn() { echo "[clone][warn] $*" >&2; }
err() { echo "[clone][error] $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_WORKSPACE_ROOT="/workspaces"
if [[ ! -d "$DEFAULT_WORKSPACE_ROOT" ]]; then
  DEFAULT_WORKSPACE_ROOT="$(dirname "$ROOT_DIR")"
fi

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$DEFAULT_WORKSPACE_ROOT}"
DEVCONTAINER_FILE="${DEVCONTAINER_FILE:-$ROOT_DIR/.devcontainer/devcontainer.json}"
ALLOW_WILDCARD="${ALLOW_WILDCARD:-0}"
FILTER_BY_WORKSPACE="${FILTER_BY_WORKSPACE:-1}"

PYTHON_JSON_AVAILABLE=0
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import json' >/dev/null 2>&1; then
    PYTHON_JSON_AVAILABLE=1
  fi
fi

jq_repo_keys() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  jq -r '(.customizations.codespaces.repositories // {}) | keys[]?' "$file" 2>/dev/null || true
}

path_within() {
  local child parent
  if ! command -v realpath >/dev/null 2>&1; then
    return 1
  fi

  child="$(realpath -m "$1" 2>/dev/null)" || return 1
  parent="$(realpath -m "$2" 2>/dev/null)" || return 1

  if [[ "$child" == "$parent" ]]; then
    return 0
  fi

  case "$child" in
    "$parent"/*) return 0 ;;
  esac

  return 1
}

if path_within "$WORKSPACE_ROOT" "$ROOT_DIR"; then
  warn "WORKSPACE_ROOT ($WORKSPACE_ROOT) lives inside the meta workspace ($ROOT_DIR); using the parent directory instead to avoid recursive clones."
  WORKSPACE_ROOT="$(dirname "$ROOT_DIR")"
fi

if [[ -z "${WORKSPACE_FILE:-}" ]]; then
  mapfile -t __ws_candidates < <(find "$ROOT_DIR" -maxdepth 1 -name "*.code-workspace" -print 2>/dev/null)
  if (( ${#__ws_candidates[@]} > 0 )); then
    WORKSPACE_FILE="${__ws_candidates[0]}"
  fi
  unset __ws_candidates
fi

pick_mode() {
  local requested="${CLONE_WITH:-auto}"
  case "$requested" in
    gh|ssh|https|https-pat) echo "$requested"; return 0 ;;
    auto)
      if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
        echo "gh"; return 0
      fi
      if command -v ssh >/dev/null 2>&1 && [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        echo "ssh"; return 0
      fi
      if [[ -n "${GH_MULTI_REPO_PAT:-}" ]]; then
        echo "https-pat"; return 0
      fi
      echo "https"; return 0
      ;;
    *)
      warn "Unknown CLONE_WITH value '$requested'; falling back to https"
      echo "https"
      return 0
      ;;
  esac
}

collect_repo_specs() {
  if (( PYTHON_JSON_AVAILABLE )); then
    python3 - "$DEVCONTAINER_FILE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    sys.exit(0)
repos = (
    data.get("customizations", {})
        .get("codespaces", {})
        .get("repositories", {})
)
for key in repos.keys():
    print(key)
PY
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    jq_repo_keys "$DEVCONTAINER_FILE"
    return 0
  fi

  warn "Unable to read repository declarations; install python3 with the json module or jq."
}

expand_wildcard() {
  local pattern="$1"
  local owner="${pattern%%/*}"
  local remainder="${pattern#*/}"

  if [[ "$remainder" != "*" ]]; then
    warn "Unsupported wildcard pattern '$pattern'; only owner/* is supported"
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    warn "Cannot expand wildcard '$pattern' because GitHub CLI is unavailable"
    return 0
  fi

  log "Expanding wildcard '$pattern' via gh repo list"
  gh repo list "$owner" --limit 200 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null || true
}

filter_specs_by_workspace() {
  local specs_json
  specs_json="$1"
  shift
  if (( PYTHON_JSON_AVAILABLE )); then
    python3 - "$WORKSPACE_FILE" "$specs_json" <<'PY'
import json, os, sys
ws_path, specs_blob = sys.argv[1], sys.argv[2]
try:
    with open(ws_path, encoding="utf-8") as fh:
        ws = json.load(fh)
except FileNotFoundError:
    sys.exit(0)
names = set()
for folder in ws.get("folders", []):
    path = folder.get("path")
    if not path:
        continue
    norm = os.path.normpath(path)
    if norm in (".", "./", "../"):
        continue
    leaf = os.path.basename(norm)
    if leaf == ".devcontainer":
        continue
    names.add(leaf)
specs = json.loads(specs_blob)
for spec in specs:
    repo_name = spec.split("/", 1)[-1]
    if repo_name in names:
        print(spec)
PY
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "Cannot filter repositories by workspace; jq is unavailable and python3 lacks the json module."
    return 0
  fi

  declare -A __workspace_names=()
  while IFS= read -r __folder_path; do
    [[ -z "$__folder_path" ]] && continue
    local __leaf
    if command -v realpath >/dev/null 2>&1; then
      local __norm
      __norm="$(realpath -m "$ROOT_DIR/$__folder_path" 2>/dev/null)" || continue
      __leaf="$(basename "$__norm")"
    else
      __leaf="$(basename "$__folder_path")"
    fi
    [[ "$__leaf" == "." || "$__leaf" == ".." || "$__leaf" == ".devcontainer" ]] && continue
    __workspace_names["$__leaf"]=1
  done < <(jq -r '(.folders // [])[] | (.path? // empty)' "$WORKSPACE_FILE" 2>/dev/null || true)

  [[ ${#__workspace_names[@]} -eq 0 ]] && return 0

  mapfile -t __spec_list < <(jq -r '.[]?' <<<"$specs_json" 2>/dev/null || true)
  for __spec in "${__spec_list[@]}"; do
    [[ -z "$__spec" ]] && continue
    local __repo_name="${__spec#*/}"
    if [[ -n "${__workspace_names[$__repo_name]:-}" ]]; then
      printf '%s\n' "$__spec"
    fi
  done
}

clone_or_update() {
  local owner_repo="$1"
  local dest_dir="$2"
  local target="$WORKSPACE_ROOT/$dest_dir"

  if path_within "$target" "$ROOT_DIR"; then
    warn "Skipping $owner_repo because target $target would reside inside the meta workspace directory ($ROOT_DIR). Adjust WORKSPACE_ROOT if this was intentional."
    return 0
  fi

  mkdir -p "$WORKSPACE_ROOT"

  if [[ -d "$target/.git" ]]; then
    log "Updating $owner_repo in $target"
    git -C "$target" fetch --all --prune || warn "Fetch failed for $dest_dir"
    return 0
  fi

  log "Cloning $owner_repo → $target"
  case "$MODE" in
    gh)
      gh repo clone "$owner_repo" "$target" -- --origin origin
      ;;
    ssh)
      git clone "git@github.com:${owner_repo}.git" "$target"
      ;;
    https-pat)
      if [[ -z "${GH_MULTI_REPO_PAT:-}" ]]; then
        err "GH_MULTI_REPO_PAT must be set when using https-pat mode"
        return 1
      fi
      git clone "https://${GH_MULTI_REPO_PAT}@github.com/${owner_repo}.git" "$target"
      git -C "$target" remote set-url origin "https://github.com/${owner_repo}.git"
      ;;
    https)
      git clone "https://github.com/${owner_repo}.git" "$target" || {
        err "HTTPS clone failed for ${owner_repo}. Check permissions or authentication."
        return 1
      }
      ;;
  esac
}

main() {
  MODE="$(pick_mode)"
  log "Clone mode: $MODE"
  log "Workspace root: $WORKSPACE_ROOT"
  log "Devcontainer manifest: $DEVCONTAINER_FILE"

  if [[ ! -f "$DEVCONTAINER_FILE" ]]; then
    err "devcontainer.json not found at $DEVCONTAINER_FILE"
    exit 1
  fi

  mapfile -t raw_specs < <(collect_repo_specs)
  if (( ${#raw_specs[@]} == 0 )); then
    warn "No repositories declared under customizations.codespaces.repositories"
    exit 0
  fi

  declare -a candidates=()
  declare -a deferred=()

  for spec in "${raw_specs[@]}"; do
    if [[ "$spec" == *"*"* ]]; then
      if [[ "$ALLOW_WILDCARD" == "1" ]]; then
        deferred+=("$spec")
      else
        warn "Ignoring wildcard '$spec'; set ALLOW_WILDCARD=1 to enable expansion"
      fi
    else
      candidates+=("$spec")
    fi
  done

  for pattern in "${deferred[@]}"; do
    while IFS= read -r expanded; do
      [[ -z "$expanded" ]] && continue
      candidates+=("$expanded")
    done < <(expand_wildcard "$pattern")
  done

  if (( ${#candidates[@]} == 0 )); then
    warn "No clone candidates remain after wildcard processing"
    exit 0
  fi

  # Deduplicate
  declare -A seen=()
  declare -a deduped=()
  for spec in "${candidates[@]}"; do
    if [[ -z "${seen[$spec]:-}" ]]; then
      deduped+=("$spec")
      seen["$spec"]=1
    fi
  done

  if [[ "$FILTER_BY_WORKSPACE" == "1" && -n "${WORKSPACE_FILE:-}" && -f "$WORKSPACE_FILE" ]]; then
    local json_blob
    if (( PYTHON_JSON_AVAILABLE )); then
      json_blob="$(printf '%s\n' "${deduped[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
    elif command -v jq >/dev/null 2>&1; then
      json_blob="$(printf '%s\n' "${deduped[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')"
    else
      warn "Skipping workspace filtering; neither python3 with json nor jq is available."
      mapfile -t filtered < <(printf '%s\n' "${deduped[@]}")
      json_blob=""
    fi

    if [[ -n "$json_blob" ]]; then
      mapfile -t filtered < <(filter_specs_by_workspace "$json_blob")
    fi
  else
    mapfile -t filtered < <(printf '%s\n' "${deduped[@]}")
  fi

  if (( ${#filtered[@]} == 0 )); then
    warn "Nothing to clone after applying workspace filters"
    exit 0
  fi

  for spec in "${filtered[@]}"; do
    local repo_name
    repo_name="${spec#*/}"
    clone_or_update "$spec" "$repo_name"
  done

  log "Done. Repositories are available under $WORKSPACE_ROOT."
}

main "$@"
