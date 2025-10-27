#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[post-create] $*"
}

configure_codex_mcp_servers() {
  if ! command -v codex >/dev/null 2>&1; then
    log "Codex CLI not found; skipping Codex MCP registration."
    return 0
  fi

  local browser_url="${CHROME_CDP_URL:-http://127.0.0.1:9222}"
  local headless="${CHROME_HEADLESS:-false}"
  local isolated="${CHROME_ISOLATED:-false}"
  local channel="${CHROME_CHANNEL:-stable}"

  codex mcp remove chrome-devtools >/dev/null 2>&1 || true
  if codex mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest \
    --browserUrl "$browser_url" \
    --headless "$headless" \
    --isolated "$isolated" \
    --channel "$channel"
  then
    log "Codex CLI registered chrome-devtools MCP server."
  else
    log "Codex CLI failed to register chrome-devtools MCP server (non-fatal)."
  fi

  codex mcp remove playwright >/dev/null 2>&1 || true
  if codex mcp add playwright -- npx --yes @playwright/mcp@latest; then
    log "Codex CLI registered playwright MCP server."
  else
    log "Codex CLI failed to register playwright MCP server (non-fatal)."
  fi
}

configure_claude_mcp_servers() {
  if ! command -v claude >/dev/null 2>&1; then
    log "Claude CLI not found; skipping Claude MCP registration."
    return 0
  fi

  local browser_url="${CHROME_CDP_URL:-http://127.0.0.1:9222}"
  local headless="${CHROME_HEADLESS:-false}"
  local isolated="${CHROME_ISOLATED:-false}"
  local channel="${CHROME_CHANNEL:-stable}"

  local chrome_json
  chrome_json=$(cat <<JSON
{
  "type": "stdio",
  "command": "npx",
  "args": [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browserUrl", "$browser_url",
    "--headless", "$headless",
    "--isolated", "$isolated",
    "--channel", "$channel"
  ],
  "env": {
    "CHROME_CDP_URL": "$browser_url",
    "CHROME_HEADLESS": "$headless",
    "CHROME_ISOLATED": "$isolated",
    "CHROME_CHANNEL": "$channel"
  }
}
JSON
)

  if claude mcp add-json chrome-devtools "$chrome_json" >/dev/null 2>&1; then
    log "Claude CLI registered chrome-devtools MCP server."
  else
    log "Claude CLI failed to register chrome-devtools MCP server (non-fatal)."
  fi

  local playwright_json
  playwright_json=$(cat <<'JSON'
{
  "type": "stdio",
  "command": "npx",
  "args": ["--yes", "@playwright/mcp@latest"]
}
JSON
)

  if claude mcp add-json playwright "$playwright_json" >/dev/null 2>&1; then
    log "Claude CLI registered playwright MCP server."
  else
    log "Claude CLI failed to register playwright MCP server (non-fatal)."
  fi
}

log "Configuring agent MCP servers via local CLIs..."
configure_codex_mcp_servers
configure_claude_mcp_servers

( npx -y chrome-devtools-mcp@latest --help >/dev/null 2>&1 || true )
( npx --yes @playwright/mcp@latest --version >/dev/null 2>&1 || true )

