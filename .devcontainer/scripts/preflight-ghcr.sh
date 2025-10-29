#!/usr/bin/env bash
set -euo pipefail

# Quick check: is Docker installed and running?
if ! command -v docker >/dev/null 2>&1; then
  echo "[preflight] Docker is not installed or not on PATH."
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "[preflight] Docker daemon not running."
  exit 1
fi

# Determine if we already have auth for ghcr.io
CONFIG="${HOME}/.docker/config.json"
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  AUTH_PRESENT="$(jq -r '.auths["ghcr.io"].auth // empty' "$CONFIG")"
else
  AUTH_PRESENT=""
fi

if [ -n "${AUTH_PRESENT}" ]; then
  echo "[preflight] ghcr.io credentials found in Docker config."
  exit 0
fi

# No stored creds → try to login using env vars (Codespaces/CI), else guide the user
if [ -n "${GHCR_PAT:-}" ]; then
  USERNAME="${GHCR_USER:-${USER}}"
  echo "[preflight] Logging into ghcr.io as ${USERNAME} using GHCR_PAT..."
  echo "${GHCR_PAT}" | docker login ghcr.io -u "${USERNAME}" --password-stdin || {
    echo "[preflight] docker login failed. Check token scopes (Packages: Read) and SSO."
    exit 1
  }
  echo "[preflight] ghcr.io login successful."
  exit 0
fi

cat <<'EOPROMPT'
[preflight] No ghcr.io credentials detected.

Do one of the following:

1) (Recommended) One-time host login (persists in OS keychain):
   docker logout ghcr.io || true
   read -s GHCR_PAT && echo "$GHCR_PAT" | docker login ghcr.io -u "<your-github-username>" --password-stdin

   Token requirements (Fine-grained PAT):
     - Resource owner: airnub-labs
     - Repository access: select the image-publishing repo(s) (e.g. devcontainers-catalog, devcontainer-images)
     - Repository permissions: Contents: Read-only
     - Account permissions: Packages: Read
     - Enable SSO for airnub-labs on the token page

2) (Ephemeral) Export and reopen:
   GHCR_USER="<your-gh>" GHCR_PAT="ghp_***" code .

EOPROMPT
exit 1
