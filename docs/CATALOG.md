# Feature and Template Catalog

## Features

| Feature | Description | Key Options |
| --- | --- | --- |
| `supabase-cli` | Installs the Supabase CLI with optional helper scripts. | `version`, `manageLocalStack`, `projectRef` |
| `chrome-cdp` | Headless Chrome with DevTools Protocol endpoint managed by supervisord. | `channel`, `port` |
| `mcp-clis` | Installs Codex, Claude, and Gemini CLIs via pnpm. | `installCodex`, `installClaude`, `installGemini`, `versions` |
| `docker-in-docker-plus` | Adds Buildx/BuildKit ergonomics on top of Docker-in-Docker. | _none_ |
| `cuda-lite` | Installs CUDA runtime when a GPU is present. | _none_ |

## Templates

| Template | Base Image | Included Features | Notes |
| --- | --- | --- | --- |
| `web` | `ghcr.io/airnub-labs/dev-web` (optional build) | `chrome-cdp`, `supabase-cli` | Template options control prebuilt image usage and CDP settings. |
| `nextjs-supabase` | `ghcr.io/airnub-labs/dev-web` | `chrome-cdp`, `supabase-cli`, `mcp-clis` | Optional Next.js scaffold with Supabase auth helpers. |
| `classroom-studio-webtop` | `ghcr.io/airnub-labs/dev-web` + `lscr.io/linuxserver/webtop` sidecar | `supabase-cli`, `mcp-clis` | Managed Chrome policies and forwarded desktop via noVNC. |

Refer to [`VERSIONING.md`](../VERSIONING.md) for published tags and digests.
