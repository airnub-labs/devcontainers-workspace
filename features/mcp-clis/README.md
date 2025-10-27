# MCP CLIs Feature

Installs Model Context Protocol client CLIs for Codex, Claude, and Gemini using `pnpm`. Each CLI can be toggled individually and version-pinned.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `installCodex` | boolean | `true` | Install the Codex CLI (`@openai/codex`). |
| `installClaude` | boolean | `false` | Install the Claude CLI (`@anthropic-ai/claude-code`). |
| `installGemini` | boolean | `false` | Install the Gemini CLI (`@google/gemini-cli`). |
| `versions` | object | `{}` | Optional map of `{ codex, claude, gemini }` → version strings. |

The feature skips installation if a CLI binary is already on the `PATH` or if `pnpm` is unavailable.
