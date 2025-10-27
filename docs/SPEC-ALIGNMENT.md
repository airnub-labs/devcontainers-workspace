# Dev Container Spec Alignment

This repository separates **Features**, **Templates**, and **Images** to align with the Dev Container specification.

- **Features** (`features/*`) are OCI-friendly installers. Each feature contains only a `devcontainer-feature.json`, an idempotent `install.sh`, and documentation. No lifecycle hooks or project scaffolding are embedded.
- **Templates** (`templates/*`) package ready-to-use `.devcontainer` payloads. They may apply features, wire up multi-container topologies, and run optional project scaffolding inside `postCreate.sh`.
- **Images** (`images/*`) provide prebuilt bases published to GHCR for faster Codespaces start times. Templates can opt in through template options (`usePrebuiltImage`).

The repository includes CI workflows to validate features, build/push images, and smoke-test each template with `devcontainer build` to ensure parity with the spec across Linux host architectures.

## Multi-repository onboarding

- Each template's `.devcontainer/devcontainer.json` declares a `customizations.codespaces.repositories` block so GitHub Codespaces pre-clones the canonical lesson starter repository.
- A portable fallback lives alongside every template: `.devcontainer/workspace.repos.yaml` pairs with `scripts/ws-clone` to hydrate the workspace whenever Codespaces pre-clone hooks are unavailable. The helper short-circuits gracefully if `yq`/`jq` are missing, keeping the experience portable across local containers and Dev Containers CLI flows.

## Sidecar development experience

- The classroom template wires a `webtop` sidecar into `docker-compose` for a browser-accessible desktop. Policies mount read-only, and the forwarded port is labeled "Desktop (webtop)" for discoverability.
- Score checks rely on `yq` (with a `grep` fallback) to inspect Compose payloads, avoiding brittle string comparisons and honoring the Dev Container spec guidance around multi-container workspaces.
