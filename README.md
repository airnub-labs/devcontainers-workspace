# Airnub Meta Workspace

This repo is a thin consumer of the **Airnub DevContainers Catalog**. It **materializes** a Template (a “stack” flavor) into `.devcontainer/`, provides a `.code-workspace`, and (optionally) clones project repos into `apps/` on first open.

## Dev Containers mental model

- **Features** → install tooling (Supabase CLI, Node, CUDA, etc.). No services, idempotent.
- **Templates** → ship a ready-to-use `.devcontainer/` payload (can be multi-container via Compose).
- **Images** → prebuilt base(s) to speed builds.

There’s **no formal “Stack”** in the spec. In our ecosystem, a **stack is just a flavor of Template** in the catalog:

- `templates/stack-nextjs-supabase-webtop/`
- `templates/stack-nextjs-supabase-novnc/`

Each stack Template includes:

- `dockerComposeFile` (e.g., `dev` + `redis` + GUI sidecar `webtop`/`novnc`)
- Port labels (9222 CDP, 3001/6080 desktop, 6379 Redis)
- Chosen Features (Node, Supabase CLI, agent CLIs, etc.)

## Materialize a stack

```bash
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh
# or
TEMPLATE=stack-nextjs-supabase-novnc scripts/sync-from-catalog.sh
```

Open the repo in VS Code or Codespaces; it will use the materialized `.devcontainer/`.

### Authenticate to GHCR (fixes `No manifest found` errors)

The dev container uses the private image `ghcr.io/airnub-labs/devcontainer-images/dev-web`. If Docker can't reach it you will see an error similar to:

```
Server did not provide instructions to authentiate! (Required: A 'WWW-Authenticate' Header)
Error fetching image details: No manifest found for ghcr.io/airnub-labs/devcontainer-images/dev-web:latest.
```

Create a [classic personal access token](https://github.com/settings/tokens/new) with the **`read:packages`** scope (and optionally `repo` if you want git access). Then, before reopening the dev container:

```bash
export GHCR_USER=<your-github-username>
export GHCR_PAT=<the-token-string>
```

The `initializeCommand` in `.devcontainer/devcontainer.json` automatically logs into GHCR using these environment variables, so the private image can be pulled successfully. Re-run the **Dev Containers: Rebuild and Reopen in Container** command afterwards.

## Supabase/Redis model

In the catalog Template (stack) via Compose sidecars and/or via Supabase CLI Feature in `postStart`.

Prefer CLI-managed local; provide separate stack flavor for a fully containerized Supabase if needed.

## Taxonomy (cheat sheet)

- **Feature** = “Install this tool.”
- **Template** = “Bring these containers + ports + policies together.”
- **Image** = “Prebaked base for the dev container (optional).”
- **Stack** = “An opinionated Template (plus optional matching Image) with a tested combo: Node + pnpm + Redis + Supabase + GUI + CDP.”
- **Meta Workspace** = “A repo that materializes a Stack Template, adds a `.code-workspace`, and (optionally) auto-clones project repos.”

## Reproducibility

Pin `CATALOG_REF` to a tag/commit. Stacks may publish a `stack.lock.json` in the catalog to pin feature versions and image digests.

