# Dev Container Spec Alignment

This repository separates **Features**, **Templates**, and **Images** to align with the Dev Container specification.

- **Features** (`features/*`) are OCI-friendly installers. Each feature contains only a `devcontainer-feature.json`, an idempotent `install.sh`, and documentation. No lifecycle hooks or project scaffolding are embedded.
- **Templates** (`templates/*`) package ready-to-use `.devcontainer` payloads. They may apply features, wire up multi-container topologies, and run optional project scaffolding inside `postCreate.sh`.
- **Images** (`images/*`) provide prebuilt bases published to GHCR for faster Codespaces start times. Templates can opt in through template options (`usePrebuiltImage`).

The repository includes CI workflows to validate features, build/push images, and smoke-test each template with `devcontainer build` to ensure parity with the spec across Linux host architectures.
