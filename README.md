# Airnub Meta Workspace

This repo is a thin consumer of the **Airnub DevContainers Catalog**. It **materializes** a Template (a "stack" flavor) into `.devcontainer/`, provides a `.code-workspace`, and (optionally) clones project repos into `apps/` on first open.

**📚 [Complete Documentation](docs/index.md)** | **🔍 [Troubleshooting](docs/reference/troubleshooting.md)** | **🏗️ [Architecture](docs/architecture/overview.md)**

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

## Understanding the System

**New to Dev Containers or this workspace?** Read the [Core Concepts](docs/getting-started/concepts.md) guide to understand:
- Features, Templates, Images (Dev Container building blocks)
- Stacks, Meta Workspace, Catalog (our terminology)
- How the shared services model works

**Quick summary:**
- **Templates** define complete dev environments (multi-container via Compose)
- **Stacks** are opinionated Template flavors (e.g., `stack-nextjs-supabase-webtop`)
- **This repo** materializes Templates from the catalog and shares services across projects

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

## Next Steps

After opening the workspace:
1. **Start Supabase:** Run `supabase start -o env` to launch the shared stack
2. **Use a project:** Run `airnub use ./your-project` to switch projects and apply migrations
3. **Access GUI:** Open port 6080 (noVNC) or 3001 (Webtop) in your browser
4. **Read the docs:** See [complete documentation](docs/index.md) for detailed guides

**Key Documentation:**
- **[Core Concepts](docs/getting-started/concepts.md)** - Understand the terminology
- **[Supabase Operations](docs/guides/supabase-operations.md)** - Working with the database
- **[Architecture Overview](docs/architecture/overview.md)** - How everything fits together
- **[Troubleshooting](docs/reference/troubleshooting.md)** - Common issues and solutions

## Reproducibility

Pin `CATALOG_REF` to a tag/commit. Stacks may publish a `stack.lock.json` in the catalog to pin feature versions and image digests.

