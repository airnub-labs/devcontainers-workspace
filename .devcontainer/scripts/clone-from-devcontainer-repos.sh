#!/usr/bin/env bash
return 0
fi
local names=()
mapfile -t names < <(json_get_workspace_folders "$WORKSPACE_FILE")
if [[ ${#names[@]} -eq 0 ]]; then
printf '%s\n' "${repos[@]}"
return 0
fi
local allow="|$(printf '%s|' "${names[@]}")"
printf '%s\n' "${repos[@]}" | awk -F/ -v a="$allow" 'index(a, $2"|")>0'
}


clone_or_update() {
local owner_repo="$1" dest_dir="$2"
local target="$WORKSPACE_ROOT/$dest_dir"


if [[ -d "$target/.git" ]]; then
log "Updating $owner_repo in $target"
git -C "$target" fetch --all --prune || warn "fetch failed for $dest_dir"
return 0
fi


log "Cloning $owner_repo → $target"
mkdir -p "$WORKSPACE_ROOT"


case "$MODE" in
gh)
gh repo clone "$owner_repo" "$target" -- --origin origin ;;
ssh)
git clone "git@github.com:${owner_repo}.git" "$target" ;;
https-pat)
[[ -n "${GH_MULTI_REPO_PAT:-}" ]] || { err "GH_MULTI_REPO_PAT not set"; exit 3; }
git clone "https://${GH_MULTI_REPO_PAT}@github.com/${owner_repo}.git" "$target"
git -C "$target" remote set-url origin "https://github.com/${owner_repo}.git" ;;
https)
git clone "https://github.com/${owner_repo}.git" "$target" || {
err "HTTPS clone failed (private repo?). Authenticate or set permissions."; exit 4
} ;;
esac
}


main() {
MODE=$(pick_mode)
log "Clone mode: $MODE"
log "Devcontainer: $DEVCONTAINER_FILE"
[[ -f "$DEVCONTAINER_FILE" ]] || { err "devcontainer.json not found: $DEVCONTAINER_FILE"; exit 1; }


mapfile -t initial < <(collect_repo_specs)
if [[ ${#initial[@]} -eq 0 ]]; then
warn "No clone candidates collected from devcontainer.json"; exit 0
fi


local to_clone
if [[ "$FILTER_BY_WORKSPACE" == "1" && -n "$WORKSPACE_FILE" && -f "$WORKSPACE_FILE" ]]; then
mapfile -t to_clone < <(printf '%s\n' "${initial[@]}" | filter_by_workspace)
else
mapfile -t to_clone < <(printf '%s\n' "${initial[@]}")
fi


if [[ ${#to_clone[@]} -eq 0 ]]; then
warn "Nothing to clone after filtering"; exit 0
fi


for spec in "${to_clone[@]}"; do
repo_name=${spec#*/}
clone_or_update "$spec" "$repo_name"
done


log "Done. Repos are under $WORKSPACE_ROOT."
}


main "$@"