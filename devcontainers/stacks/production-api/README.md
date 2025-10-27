# AirNub production API stack

Optimised for backend and automation repos that need Supabase locally plus persistent pnpm caches when running in Codespaces or locally.

## Components

- Template: [`templates/api-only`](../../templates/api-only)
- Features: Docker-in-Docker helpers, Supabase stack

## Forwarded ports

| Service | Port |
| ------- | ---- |
| Web app preview | 3000, 3100 |
| Supabase API & Studio | 54321 – 54327 |
| Redis | 6379 |

## Recommended devices

- Desktop VS Code on macOS, Windows, or Linux
- GitHub Codespaces in the browser (Chrome, Edge, Firefox)
- Self-hosted runners for CI validation (Docker required)
