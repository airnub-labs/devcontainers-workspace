# AirNub full GUI workspace template

Builds on the base template by enabling graphical tooling, Docker-in-Docker, and helper scripts that prep Codespaces or local containers for visual debugging.

## What it adds

- Docker-in-Docker with helper scripts so browsers, Supabase, and Redis can run inside the container.
- GUI tooling feature to provision web-based desktops (noVNC/Webtop) and headless Chrome access.
- Persistent GUI configuration volume mapped at `/home/vscode/.config/gui`.
- Default port forwards for the GUI dashboards (6080/6081) and Chrome DevTools (9222), alongside common web app ports.

## When to use it

Choose this template when demoing front-end flows, recording walkthroughs, or teaching workshops that rely on a browser in the container. It still includes the base Node.js, pnpm, and Python toolchain so full-stack apps run without extra setup.
