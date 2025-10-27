# Agent tooling CLIs feature

This feature installs the command line tools shipped with the major coding agents so they are available inside a Dev Container or GitHub Codespace. Each tool can be toggled independently via feature options:

| Option | Default | Description |
| --- | --- | --- |
| `installCodex` | `false` | Installs the OpenAI Codex CLI (`codex`). |
| `installClaude` | `false` | Installs the Anthropic Claude Code CLI (`claude`). |
| `installGemini` | `false` | Installs the Google Gemini CLI (`gemini`). |

If `npm` is available the feature installs the package globally. When a CLI cannot be installed (for example, `npm` is missing or offline), the feature drops a small shim in `/usr/local/bin` that proxies to `npx --yes <package>` so the command name still resolves at runtime.

The feature intentionally avoids configuring any MCP servers or editor-specific behaviour. Projects should use template post-create hooks or checked-in client configuration files to register MCP servers with the installed CLIs.
