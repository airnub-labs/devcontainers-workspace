# docs/CATALOG-ARCHITECTURE.md (v0.2)

## Components
- **Features** (`features/*`): reusable installers; idempotent, no services, no secrets.
- **Templates** (`templates/*`): multi-container orchestration and options.
- **Images** (`images/*`): prebuilt bases; multi-arch publication.

### Feature principles
- `devcontainer-feature.json` with schema + defaults.
- `install.sh` idempotent; no Docker; non-root friendly.
- Example feature IDs: `supabase-cli@1`, `chrome-cdp@1`, `agent-tooling-clis@1`, `docker-in-docker-plus@1`, `cuda-lite@1`.

### Template principles
- Own `dockerComposeFile`, `runServices`, sidecars, port labels.
- Options via `devcontainer-template.json`.
- Workspaces **materialize** the template; VS Code does not pull templates at open time.

### Images
- Publish to GHCR with provenance + SBOM; consumers may **pin digests** in compose files.

---
