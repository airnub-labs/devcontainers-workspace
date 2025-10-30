# Airnub Meta Workspace

This repo is a thin consumer of the **Airnub DevContainers Catalog**. It **materializes** a Template (a "stack" flavor) into `.devcontainer/`, provides a `.code-workspace`, and (optionally) clones project repos into `apps/` on first open.

**📚 [Complete Documentation](docs/index.md)** | **🔍 [Troubleshooting](docs/reference/troubleshooting.md)** | **🏗️ [Architecture](docs/docker-containers.md)**

## Private GHCR Quick Start (one-time setup)

If the devcontainer image is private, you must authenticate to ghcr.io before opening this workspace in a container.

### A) Create a Fine-grained PAT (read-only for pulls)

Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.

Resource owner: airnub-labs (your org).

Repository access:

Choose Only select repositories and select the repo(s) that publish images, e.g.:

- devcontainers-catalog (if images are published from here), and/or
- devcontainer-images (if you split images into a dedicated repo).

Permissions:

Repository permissions

Contents: Read-only (required for repo association).

Account permissions

Packages: Read ✅ (this is the key for GHCR pulls)

Create token, then on the token page click Enable SSO for airnub-labs.

For publishing in CI, create a separate fine-grained PAT (short expiry) with Packages: Write, or use GITHUB_TOKEN in Actions.

### B) One-time host login (stores creds in your OS keychain)

```bash
docker logout ghcr.io || true
read -s GHCR_PAT && echo "$GHCR_PAT" | docker login ghcr.io -u "<your-github-username>" --password-stdin
# (paste the fine-grained PAT when prompted; nothing is echoed)
```

After this, Dev Containers/Compose can pull without environment variables.
If your org enforces SSO, make sure you pressed Enable SSO on the token.

### C) Codespaces (if applicable)

Add Repository secrets on this workspace repo:

- `GHCR_USER` = your GitHub username
- `GHCR_PAT` = fine-grained PAT with Packages: Read, SSO enabled

The workspace will preflight-login automatically on start.

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

