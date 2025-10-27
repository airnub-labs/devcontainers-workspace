# AirNub base workspace template

This template packages the core tooling shared across AirNub projects so other templates and stacks can layer on top of a consistent baseline.

## Included tooling

- Ubuntu 24.04 base image configured through Docker Compose.
- Node.js 24 with pnpm 10 preinstalled via the official Dev Containers feature.
- Python 3.12 configured through the Dev Containers Python feature.
- Common utilities (Git, curl, zsh) with the default `vscode` user.
- Shared VS Code settings enabling format-on-save, ESLint fixes, and Python IntelliSense.
- A reusable `global-pnpm-store` volume so pnpm packages persist between rebuilds.

## Usage

Reference this template directly or layer other templates on top of it via `dockerComposeFile` and `features` overrides. The workspace folder resolves to `/workspaces/<repo>` so multi-repo workflows match the rest of the meta workspace.
