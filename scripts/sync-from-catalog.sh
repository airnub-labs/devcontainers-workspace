#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
: "${CATALOG_OWNER:=airnub-labs}"
: "${CATALOG_REPO:=devcontainers-catalog}"
: "${CATALOG_REF:=main}"
: "${TEMPLATE:=classroom-studio-webtop}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
ARCHIVE_URL="https://codeload.github.com/${CATALOG_OWNER}/${CATALOG_REPO}/tar.gz/refs/heads/${CATALOG_REF}"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "[sync] Fetching ${CATALOG_OWNER}/${CATALOG_REPO}@${CATALOG_REF}"
curl -fsSL "$ARCHIVE_URL" -o "$TMP/catalog.tgz"

# Optional SHA256 verification
# echo "<sha256sum>  $TMP/catalog.tgz" | sha256sum -c -

tar -xzf "$TMP/catalog.tgz" -C "$TMP"
SRC="$(find "$TMP" -maxdepth 1 -type d -name "${CATALOG_REPO}-*" | head -n1)"
TPL="$SRC/templates/${TEMPLATE}"

if [[ -z "$SRC" ]]; then
  echo "[sync] Failed to locate extracted catalog directory" >&2
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

if [[ -d "$TPL/.template/.devcontainer" ]]; then
  cp -a "$TPL/.template/.devcontainer/." "$ROOT/.devcontainer/"
else
  echo "[sync] Template has no payload; seeding minimal compose"
  cat > "$ROOT/.devcontainer/compose.yaml" <<'YAML'
services:
  dev:
    image: mcr.microsoft.com/devcontainers/base:ubuntu
    user: "vscode"
    volumes:
      - ..:/workspaces:cached
    shm_size: "2gb"
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
  webtop:
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - CUSTOM_USER=vscode
    volumes:
      - ..:/workspace
    ports:
      - "3001:3000"
    shm_size: "2gb"
YAML
fi

if [[ ! -f "$ROOT/.devcontainer/devcontainer.json" ]]; then
  cat > "$ROOT/.devcontainer/devcontainer.json" <<'JSON'
{
  "name": "airnub — workspace (webtop)",
  "dockerComposeFile": ["./compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "redis", "webtop"],

  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",

  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "24", "installPnpm": true },
    "ghcr.io/devcontainers/features/python:1": { "version": "3.12" },
    "ghcr.io/devcontainers/features/deno:1": {}

    /* Switch to your catalog features when published:
    "ghcr.io/airnub-labs/devcontainer-features/supabase-cli:1": { "manageLocalStack": true },
    "ghcr.io/airnub-labs/devcontainer-features/chrome-cdp:1": { "port": 9222 },
    "ghcr.io/airnub-labs/devcontainer-features/agent-tooling-clis:1": {},
    "ghcr.io/airnub-labs/devcontainer-features/docker-in-docker-plus:1": {}
    */
  },

  "containerEnv": {
    "PNPM_HOME": "/home/vscode/.local/share/pnpm",
    "PNPM_STORE_PATH": "/home/vscode/.pnpm-store",
    "CHROME_CDP_URL": "http://127.0.0.1:9222"
  },

  "mounts": [
    "source=global-pnpm-store,target=/home/vscode/.pnpm-store,type=volume"
  ],

  "forwardPorts": [9222, 3001, 6080, 6379, 54323],
  "portsAttributes": {
    "3001": { "label": "Webtop (Desktop)", "visibility": "private", "requireLocalPort": false },
    "6080": { "label": "noVNC (Desktop)", "visibility": "private", "requireLocalPort": false },
    "9222": { "label": "Chrome DevTools (CDP)", "visibility": "private", "requireLocalPort": false },
    "6379": { "label": "Redis", "onAutoForward": "silent" },
    "54323": { "label": "Supabase Studio", "onAutoForward": "notify" }
  },

  "postCreateCommand": "bash .devcontainer/postCreate.sh",
  "postStartCommand": "bash .devcontainer/postStart.sh",

  "customizations": {
    "vscode": {
      "settings": {
        "typescript.tsdk": "node_modules/typescript/lib",
        "editor.formatOnSave": true,
        "workbench.activityBar.location": "top",
        "workbench.colorTheme": "Default Dark Modern",
        "workbench.startupEditor": "readme",
        "chat.mcp.gallery.enabled": true
      },
      "extensions": [
        "ms-azuretools.vscode-docker",
        "ms-playwright.playwright",
        "denoland.vscode-deno",
        "Supabase.vscode-supabase-extension",
        "Redis.redis-for-vscode",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "deque-systems.vscode-axe-linter",
        "DavidAnson.vscode-markdownlint",
        "bradlc.vscode-tailwindcss",
        "github.vscode-github-actions",
        "openai.chatgpt",
        "google.geminicodeassist",
        "google.gemini-cli-vscode-ide-companion",
        "anthropic.claude-code"
      ],
      "mcp": {
        "servers": {
          "chrome-devtools": {
            "command": "npx",
            "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "${localEnv:CHROME_CDP_URL}"]
          },
          "playwright": { "command": "npx", "args": ["--yes", "@playwright/mcp@latest"] }
        }
      }
    }
  }
}
JSON
fi

mkdir -p "$ROOT/.devcontainer"
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

echo "✅ Synced template '${TEMPLATE}' from ${CATALOG_OWNER}/${CATALOG_REPO}@${CATALOG_REF}."
