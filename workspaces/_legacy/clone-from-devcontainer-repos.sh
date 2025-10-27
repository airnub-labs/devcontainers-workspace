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
  if [[ "$WORKSPACE_ROOT" != "$ROOT_DIR" ]]; then
    warn "WORKSPACE_ROOT ($WORKSPACE_ROOT) lives inside the meta workspace ($ROOT_DIR); using the parent directory instead to avoid recursive clones."
    WORKSPACE_ROOT="$(dirname "$ROOT_DIR")"
  else
    log "WORKSPACE_ROOT points at the meta workspace root; assuming Git ignore rules will keep nested clones untracked."
  fi
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

clone_or_update() {
  local owner_repo="$1"
  local dest_dir="$2"
  local target="$WORKSPACE_ROOT/$dest_dir"

  if path_within "$target" "$ROOT_DIR"; then
    if [[ "$WORKSPACE_ROOT" == "$ROOT_DIR" ]]; then
      log "Target $target is inside the meta workspace root; relying on .gitignore to keep it untracked."
    else
      warn "Skipping $owner_repo because target $target would reside inside the meta workspace directory ($ROOT_DIR). Adjust WORKSPACE_ROOT if this was intentional."
      return 0
    fi
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

format_project_marker_value() {
  local path="$1"

  if [[ -z "$path" ]]; then
    return 1
  fi

  if [[ ! -d "$path" ]]; then
    return 1
  fi

  local resolved
  resolved="$(cd "$path" && pwd)" || return 1

  if [[ "$resolved" == "$ROOT_DIR" ]]; then
    printf '.'
    return 0
  fi

  case "$resolved" in
    "$ROOT_DIR"/*)
      printf './%s' "${resolved#$ROOT_DIR/}"
      ;;
    *)
      printf '%s' "$resolved"
      ;;
  esac
}

initialize_current_project_marker() {
  local project_path="$1"
  local supabase_dir="$ROOT_DIR/supabase"
  local marker_file="$ROOT_DIR/.airnub-current-project"

  if [[ -s "$marker_file" ]]; then
    return 0
  fi

  local target_path=""
  if [[ -n "$project_path" && -d "$project_path" ]]; then
    target_path="$project_path"
  elif [[ -d "$supabase_dir" ]]; then
    target_path="$supabase_dir"
  fi

  if [[ -z "$target_path" ]]; then
    warn "No project directories available to initialize $marker_file"
    return 0
  fi

  local marker_value
  if ! marker_value="$(format_project_marker_value "$target_path")"; then
    warn "Unable to compute marker value for $target_path"
    return 0
  fi

  mkdir -p "$(dirname "$marker_file")"
  printf '%s\n' "$marker_value" >"$marker_file"
  log "Initialized Supabase project marker at $marker_file → $marker_value"
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

  mapfile -t filtered < <(printf '%s\n' "${deduped[@]}")

  if (( ${#filtered[@]} == 0 )); then
    warn "Nothing to clone after processing repository declarations"
    exit 0
  fi

  local first_project_path=""

  for spec in "${filtered[@]}"; do
    local repo_name
    repo_name="${spec#*/}"
    clone_or_update "$spec" "$repo_name"
    if [[ -z "$first_project_path" ]]; then
      local candidate="$WORKSPACE_ROOT/$repo_name"
      if [[ -d "$candidate" ]]; then
        first_project_path="$candidate"
      fi
    fi
  done

  initialize_current_project_marker "$first_project_path"

  log "Done. Repositories are available under $WORKSPACE_ROOT."
}

main "$@"
