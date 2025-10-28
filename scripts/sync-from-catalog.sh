#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
: "${CATALOG_OWNER:=airnub-labs}"
: "${CATALOG_REPO:=devcontainers-catalog}"
: "${CATALOG_REF:=main}"                  # pin to a tag/commit when available
: "${TEMPLATE:=stack-nextjs-supabase-webtop}"   # e.g. stack-* or any template in catalog

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
ARCHIVE_URL="https://codeload.github.com/${CATALOG_OWNER}/${CATALOG_REPO}/tar.gz/refs/heads/${CATALOG_REF}"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "[sync] Fetching ${CATALOG_OWNER}/${CATALOG_REPO}@${CATALOG_REF}"
curl -fsSL "$ARCHIVE_URL" -o "$TMP/catalog.tgz"

# Optional integrity check:
# echo "<sha256>  $TMP/catalog.tgz" | sha256sum -c -

tar -xzf "$TMP/catalog.tgz" -C "$TMP"
SRC="$(find "$TMP" -maxdepth 1 -type d -name "${CATALOG_REPO}-*" | head -n1)"
TPL="$SRC/templates/${TEMPLATE}"

if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "[sync] ERROR: Failed to locate extracted catalog source" >&2
  exit 1
fi

if [[ ! -d "$TPL" ]]; then
  echo "[sync] Template not found: ${TEMPLATE}"
  echo "[sync] Available templates:"
  ls -1 "$SRC/templates" || true
  exit 1
fi

echo "[sync] Materializing template payload -> .devcontainer/"
rm -rf "$ROOT/.devcontainer"
mkdir -p "$ROOT/.devcontainer"

# Copy the template payload
if [[ -d "$TPL/.template/.devcontainer" ]]; then
  cp -a "$TPL/.template/.devcontainer/." "$ROOT/.devcontainer/"
else
  echo "[sync] ERROR: Template has no .template/.devcontainer payload"
  exit 1
fi

# Ensure lifecycle hooks exist
[[ -f "$ROOT/.devcontainer/postCreate.sh" ]] || cat > "$ROOT/.devcontainer/postCreate.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "[postCreate] Node: $(node -v || true) | pnpm: $(pnpm -v || true) | Python: $(python --version || true)"
SH

[[ -f "$ROOT/.devcontainer/postStart.sh" ]] || cat > "$ROOT/.devcontainer/postStart.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "[postStart] Container started."
SH

chmod +x "$ROOT/.devcontainer/postCreate.sh" "$ROOT/.devcontainer/postStart.sh"

echo "✅ Synced ${TEMPLATE} from ${CATALOG_OWNER}/${CATALOG_REPO}@${CATALOG_REF}."
