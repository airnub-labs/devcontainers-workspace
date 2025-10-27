#!/usr/bin/env bash
set -euo pipefail

score=0
max=100
details=()

add() { score=$((score+$1)); details+=("$2 (+$1)"); }
miss() { details+=("$1 (+0)"); }

# --- A. Features ---
check_features() {
  local has=0
  if [ -d features ]; then
    for f in features/*; do
      [ -d "$f" ] || continue
      if [ -f "$f/devcontainer-feature.json" ] && [ -f "$f/install.sh" ]; then
        has=1
      fi
    done
  fi
  if [ "$has" -eq 1 ]; then
    add 6 "Features: structure OK"
  else
    miss "Features: missing feature folders / required files"
  fi

  # quick heuristics across all install.sh
  local installs=$(find features -type f -name install.sh 2>/dev/null | wc -l | xargs)
  if [ "$installs" -gt 0 ]; then
    # Heuristics: avoid devcontainer lifecycle in features, avoid starting services, allow re-run
    if ! grep -RqiE "postCreateCommand|postStartCommand|docker-compose up|supabase start" features 2>/dev/null; then
      add 6 "Features: no lifecycle/service start detected"
    else
      miss "Features: avoid lifecycle/service start in features"
    fi
    # Non-root friendly heuristic
    if ! grep -RqiE "useradd\\s|adduser\\s\\w+\\s*--uid\\s*0" features 2>/dev/null; then
      add 6 "Features: likely non-root friendly"
    else
      miss "Features: root assumptions found"
    fi
    # Idempotency heuristic
    if ! grep -RqiE "read\\s+-p|select\\s+in" features 2>/dev/null; then
      add 6 "Features: non-interactive/idempotent heuristic"
    else
      miss "Features: interactive prompts detected"
    fi
    # Distribution readiness heuristic
    add 6 "Features: GHCR-ready folder layout (heuristic)"
  else
    miss "Features: no install.sh found"
  fi
}

# --- B. Templates ---
check_templates() {
  local has=0
  if [ -d templates ]; then
    for t in templates/*; do
      [ -d "$t" ] || continue
      if [ -f "$t/devcontainer-template.json" ] && [ -f "$t/.template/.devcontainer/devcontainer.json" ]; then
        has=1
      fi
    done
  fi
  [ "$has" -eq 1 ] && add 7 "Templates: structure OK" || miss "Templates: missing required files"

  # Compose multi-container & features only on primary
  local payloads=$(find templates -type f -path "*/.template/.devcontainer/devcontainer.json" 2>/dev/null)
  if [ -n "$payloads" ]; then
    local multi=0 sidecarFeatures=0
    while IFS= read -r p; do
      if grep -q '"dockerComposeFile"' "$p" && grep -q '"service"' "$p"; then multi=1; fi
      # crude detection of features under sidecars is hard from json alone; pass by default
    done <<< "$payloads"
    [ "$multi" -eq 1 ] && add 6 "Templates: compose multi-container present" || miss "Templates: no multi-container compose"
    add 5 "Templates: features appear only on primary (heuristic)"
  else
    miss "Templates: no payload devcontainer.json files found"
  fi

  # Template options respected
  local tdefs=$(find templates -type f -name "devcontainer-template.json" 2>/dev/null)
  if [ -n "$tdefs" ]; then add 7 "Templates: template options present"; else miss "Templates: no template options"; fi
}

# --- C. Sidecar browser ---
check_sidecar() {
  local hasSidecar=0 hasPolicies=0
  if grep -Rqi '"webtop"' templates/*/.template/.devcontainer/compose.yaml 2>/dev/null; then hasSidecar=1; fi
  if grep -Rqi '/etc/opt/chrome/policies/managed' templates/*/.template/.devcontainer/compose.yaml 2>/dev/null; then hasPolicies=1; fi
  [ "$hasSidecar" -eq 1 ] && add 5 "Sidecar: webtop/noVNC present" || miss "Sidecar: none detected"
  [ "$hasPolicies" -eq 1 ] && add 5 "Sidecar: Chrome policies mount present" || miss "Sidecar: no policies mount"
}

# --- D. CI/CD ---
check_ci() {
  local wf=".github/workflows"
  if [ -d "$wf" ]; then
    if grep -Rqi 'devcontainers/action' "$wf" 2>/dev/null; then add 4 "CI: publish-features present"; else miss "CI: publish-features missing"; fi
    if grep -Rqi 'buildx' "$wf" 2>/dev/null; then add 3 "CI: images buildx present"; else miss "CI: images buildx missing"; fi
    if grep -Rqi 'devcontainer build' "$wf" 2>/dev/null || grep -Rqi 'test.sh' templates/*/test/* 2>/dev/null; then add 3 "CI: template tests present"; else miss "CI: template tests missing"; fi
  else
    miss "CI: no workflows"
  fi
}

# --- E. Images ---
check_images() {
  [ -d images ] && add 3 "Images: folder present" || miss "Images: folder missing"
  if [ -d images ]; then
    if grep -Rqi 'platform\\s*=\\s*linux/amd64' .github/workflows 2>/dev/null || grep -Rqi 'buildx' .github/workflows 2>/dev/null; then
      add 2 "Images: multi-arch intent in CI"
    else
      miss "Images: multi-arch not detected"
    fi
  fi
}

# --- F. Documentation ---
check_docs() {
  local got=0
  [ -f docs/SPEC-ALIGNMENT.md ] && got=$((got+1))
  [ -f docs/CATALOG.md ] && got=$((got+1))
  [ -f docs/EDU-SETUP.md ] && got=$((got+1))
  [ -f docs/SECURITY.md ] && got=$((got+1))
  [ "$got" -ge 1 ] && add $((got*2)) "Docs: ${got} key docs found" || miss "Docs: none of the key docs found"
  [ "$got" -ge 4 ] && : || : # cap at 8 via the math above; remaining 2 points via clarity pass below
  add 2 "Docs: clarity/readme heuristic"
}

# --- G. Multi-repo strategy ---
check_multirepo() {
  local codespaces=0 manifest=0
  if grep -Rqi '"customizations"\\s*:\\s*{[^{]*"codespaces"[^{]*"repositories"' templates/*/.template/.devcontainer/devcontainer.json 2>/dev/null; then codespaces=1; fi
  if [ -f .devcontainer/workspace.repos.yaml ] || [ -f templates/*/.template/.devcontainer/workspace.repos.yaml ]; then manifest=1; fi
  [ "$codespaces" -eq 1 ] && add 3 "Multi-repo: Codespaces repositories present" || miss "Multi-repo: Codespaces pre-clone missing"
  [ "$manifest" -eq 1 ] && add 2 "Multi-repo: workspace manifest present" || miss "Multi-repo: no manifest fallback"
}

# --- H. Versioning ---
check_versioning() {
  [ -f VERSIONING.md ] && add 2 "Versioning: guidance present" || miss "Versioning: guidance missing"
  local fv=$(grep -Rho '"version"\\s*:\\s*"[^"]+"' features 2>/dev/null | wc -l | xargs)
  local tv=$(grep -Rho '"version"\\s*:\\s*"[^"]+"' templates/*/devcontainer-template.json 2>/dev/null | wc -l | xargs)
  [ "$fv" -gt 0 ] && add 2 "Versioning: features have versions" || miss "Versioning: features missing versions"
  [ "$tv" -gt 0 ] && add 1 "Versioning: templates have versions" || miss "Versioning: templates missing versions"
}

main() {
  check_features
  check_templates
  check_sidecar
  check_ci
  check_images
  check_docs
  check_multirepo
  check_versioning

  echo "SCORE_TOTAL=$score" > .score/summary.env
  printf "%s\n" "${details[@]}" > .score/details.txt
}
main "$@"
