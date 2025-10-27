# GUI tooling feature

## Purpose
Provides opinionated configuration for the workspace GUI stack. The feature refreshes `.devcontainer/.env` with the correct Docker Compose profiles and environment values so Codespaces and local builds expose the requested GUI providers (noVNC, Webtop, Chrome).

## Inputs & options
The manifest exposes a single option:

- `providers` *(string, default: `webtop`)* – comma-separated list of GUI providers to enable. Accepts `novnc`, `webtop`, `chrome`, or `all`.

In addition, the feature forwards existing environment variables from the host into the container for Chrome credentials, GUI ports, locales, and other GUI toggles via the `containerEnv` block.

## Lifecycle hooks
`updateContentCommand` runs [`bin/update-profiles.sh`](./scripts/update-profiles.sh). The script reads `.devcontainer/.env.example` and optional root-level `.env` overrides, expands the `GUI_PROVIDERS` value, and rewrites `.devcontainer/.env` so `COMPOSE_PROFILES` includes the matching `gui-*` profiles alongside the base `devcontainer` profile.

## Compatibility
Pairs with the shared templates that include GUI docker-compose services. Works in Codespaces and the Dev Containers CLI as long as the host supports Docker Compose profiles. When the requested provider is missing or misconfigured, the script exits with an error to avoid starting an inconsistent GUI stack.
