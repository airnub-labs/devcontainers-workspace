# AirNub classroom stack

This stack pairs the **full-gui** template with Supabase helpers so instructors can launch a single Codespace that exposes every service needed for live workshops.

## Components

- Template: [`templates/full-gui`](../../templates/full-gui)
- Features: GUI tooling, Docker-in-Docker helpers, Supabase stack

## Forwarded ports

| Service | Port |
| ------- | ---- |
| Web app preview | 3000, 3100 |
| GUI web desktop | 6080, 6081 |
| Chrome DevTools | 9222 |
| Supabase API & Studio | 54321 – 54327 |
| Redis | 6379 |

## Recommended devices

- Desktop VS Code on macOS, Windows, or Linux
- GitHub Codespaces in the browser (Chrome, Edge, or Firefox)

Tablets are supported via Codespaces, but external keyboards are strongly recommended for terminal-heavy exercises.
