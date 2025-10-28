# Airnub Meta Workspace


This repo is a thin consumer of the **Airnub DevContainers Catalog**. It **materializes** a Template (stack) into `.devcontainer/`, provides a `.code-workspace`, and (optionally) clones project repos from a blueprint.


## Model


- **Meta Workspace** = “A repo that materializes a Stack Template, adds a `.code-workspace`, and auto-clones project repos.”
- **Stack** = “An opinionated Template (plus optional matching Image) with a tested combo: Node + pnpm + Redis + Supabase + GUI + CDP.”


> Dev Containers primitives:
> - **Features** → install tooling (no services).
> - **Templates** → ready-to-use `.devcontainer/` payloads (multi-container via Compose).
> - **Images** → prebuilt bases for speed.


## Getting started


1. **Sync a stack from the catalog**:
   ```bash
   CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh
   ```
2. Open the repo in VS Code or Codespaces; it uses the materialized `.devcontainer/`.
3. Edit `workspace.blueprint.json` (if present) to auto-clone app repos into `/apps` on first container build.


### Why this split?

- The catalog publishes reusable Features, Templates (stacks), and Images.
- The workspace stays project-centric and reproducible by pinning a template ref.


## Ensure Codespaces-friendly workspace

- Keep `.code-workspace` paths relative to this repo so Codespaces reopens the container reliably.
- Re-run `scripts/sync-from-catalog.sh` when switching stacks to rematerialize `.devcontainer/`.
- Never commit secrets or cloned project repos; they live outside the template payload.
