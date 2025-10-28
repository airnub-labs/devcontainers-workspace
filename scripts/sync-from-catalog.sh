#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
: "${CATALOG_OWNER:=airnub-labs}"
: "${CATALOG_REPO:=devcontainers-catalog}"
: "${CATALOG_REF:=main}"
: "${TEMPLATE:=stack-nextjs-supabase-webtop}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
ARCHIVE_URL="https://codeload.github.com/${CATALOG_OWNER}/${CATALOG_REPO}/tar.gz/refs/heads/${CATALOG_REF}"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/src"

echo "[sync] Fetching ${CATALOG_OWNER}/${CATALOG_REPO}@${CATALOG_REF}" >&2
curl -fsSL "$ARCHIVE_URL" -o "$TMP/catalog.tgz"

tar -xzf "$TMP/catalog.tgz" --strip-components=1 -C "$TMP/src"
TPL_DIR="$TMP/src/templates/${TEMPLATE}"

if [[ ! -d "$TPL_DIR" ]]; then
  echo "[sync] Template not found: ${TEMPLATE}" >&2
  echo "[sync] Available templates:" >&2
  ls -1 "$TMP/src/templates" >&2 || true
  exit 1
fi

PAYLOAD="$TPL_DIR/.template/.devcontainer"

if [[ ! -d "$PAYLOAD" ]]; then
  echo "[sync] Template ${TEMPLATE} has no .template/.devcontainer payload" >&2
  exit 1
fi

echo "[sync] Materializing ${TEMPLATE} → ${ROOT}/.devcontainer" >&2
rm -rf "$ROOT/.devcontainer"
mkdir -p "$ROOT/.devcontainer"
cp -a "$PAYLOAD/." "$ROOT/.devcontainer/"

echo "[sync] Done. Reopen the repo in VS Code or Codespaces to rebuild the container." >&2
