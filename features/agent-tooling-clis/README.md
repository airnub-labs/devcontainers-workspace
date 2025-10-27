# Agent Tooling CLIs Feature

Installs coding-agent client CLIs for Codex, Claude, and Gemini using the first available Node package manager (`pnpm` preferred, `npm` fallback). Each CLI can be toggled individually and version-pinned. The feature purposely limits itself to installing binaries; configure MCP servers per project via template hooks (for example, `.devcontainer/postCreate.sh`) or editor-specific project files.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `installCodex` | boolean | `true` | Install the Codex CLI (`@openai/codex`). |
| `installClaude` | boolean | `false` | Install the Claude CLI (`@anthropic-ai/claude-code`). |
| `installGemini` | boolean | `false` | Install the Gemini CLI (`@google/gemini-cli`). |
| `versions` | object | `{}` | Optional map of `{ codex, claude, gemini }` → version strings. |

The feature skips installation if a CLI binary is already on the `PATH` or if neither `pnpm` nor `npm` is available.

## Project-scoped MCP wiring

Add MCP servers during template post-create hooks so every workspace gets the same configuration without baking behaviour into the feature itself:

```bash
# .devcontainer/postCreate.sh
if command -v claude >/dev/null 2>&1; then
  CLAUDE_JSON="$(python3 - <<'PYTHON'
import json, os
print(json.dumps({
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", os.environ.get("CHROME_CDP_URL", "http://127.0.0.1:9222")]
}))
PYTHON
  )"
  claude mcp add-json chrome-devtools "$CLAUDE_JSON" || true
fi

if command -v codex >/dev/null 2>&1; then
  codex mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl "${CHROME_CDP_URL:-http://127.0.0.1:9222}" || true
fi
```

Clients that support project configuration files (for example, `.claude/settings.json`) can instead commit their MCP definitions directly to the template payload.
