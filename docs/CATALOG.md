# Feature and Template Catalog

## Features

| Feature | Description | Key Options |
| --- | --- | --- |
| `supabase-cli` | Installs the Supabase CLI with optional helper scripts and metadata capture. | `version`, `manageLocalStack`, `services`, `projectRef` |
| `chrome-cdp` | Headless Chrome with a DevTools Protocol endpoint managed by supervisord. | `channel`, `port` |
| `agent-tooling-clis` | Installs Codex, Claude, and Gemini CLIs using pnpm/npm fallbacks. Configure MCP servers per project via template hooks. | `installCodex`, `installClaude`, `installGemini`, `versions` |
| `docker-in-docker-plus` | Adds Buildx/BuildKit ergonomics on top of Docker-in-Docker. | _none_ |
| `cuda-lite` | Installs CUDA runtime libraries only when a GPU is detected. | _none_ |

## Templates

| Template | Version | Base Image(s) | Included Features | Notes |
| --- | --- | --- | --- | --- |
| `web` | `1.0.0` | `ghcr.io/airnub-labs/dev-web` (optional local build) | `chrome-cdp`, `supabase-cli` | Options toggle the prebuilt image and CDP channel/port. |
| `nextjs-supabase` | `1.0.0` | `ghcr.io/airnub-labs/dev-web` (optional local build) | `chrome-cdp`, `supabase-cli`, `agent-tooling-clis` (optional) | Supports turnkey Next.js scaffolding with Supabase integrations. |
| `classroom-studio-webtop` | `1.0.0` | `ghcr.io/airnub-labs/dev-web` + `lscr.io/linuxserver/webtop` sidecar | `supabase-cli`, `agent-tooling-clis` | Managed/none Chrome policy presets sync into `.devcontainer/policies/managed.json`; override via the `chromePolicies` option. |

Refer to [`VERSIONING.md`](../VERSIONING.md) for published tags and digests.

---

## Workspace Variants (v0.2)

| Variant | GUI | CDP | Redis | Supabase local | Notes |
|---|---|---:|---:|---:|---|
| `workspaces/webtop` | linuxserver/webtop:ubuntu-xfce | 9222 | 6379 | CLI-managed | Desktop at 3001 |
| `workspaces/novnc` | dorowu/ubuntu-desktop-lxde-vnc | 9222 | 6379 | CLI-managed | Desktop at 6080 (audio opt. 6081) |

## Feature Matrix (selected, v0.2)

| Feature | Default Options | Provides |
|---|---|---|
| `supabase-cli@1` | `manageLocalStack: true` | `supabase` binary + helpers |
| `chrome-cdp@1` | `channel: stable`, `port: 9222` | Headless Chrome + CDP |
| `agent-tooling-clis@1` | `installCodex: true` | Agent CLIs (codex/claude/gemini opts) |
| `docker-in-docker-plus@1` | — | buildx bootstrap |
| `cuda-lite@1` | — | Minimal CUDA libs (no-op w/o GPU) |

