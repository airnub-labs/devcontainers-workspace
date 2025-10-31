# Core Concepts & Taxonomy

This guide explains the foundational concepts used throughout the Airnub Meta Workspace system. Understanding these terms will help you navigate the documentation and use the workspace effectively.

> **⚠️ Customization Note:**
> Examples in this guide use `airnub-labs` as the organization name. Replace with your own organization name where applicable.

---

## The Dev Containers Mental Model

The Dev Containers ecosystem has three core building blocks:

### **Features**
Install tooling and configure the development environment.

- **Purpose:** Install CLIs, runtimes, SDKs, or configure system settings
- **Characteristics:**
  - Idempotent (safe to run multiple times)
  - No long-running services
  - Examples: Supabase CLI, Node.js, Python, CUDA drivers
- **Implementation:** Shell scripts that modify the container during build/initialization

### **Templates**
Ship a ready-to-use `.devcontainer/` configuration payload.

- **Purpose:** Provide complete, pre-configured development environments
- **Characteristics:**
  - Can be single-container or multi-container (via Docker Compose)
  - Include feature specifications, port forwarding, VS Code customizations
  - Contain `devcontainer.json` and related configuration files
- **Examples:**
  - Basic Node.js environment
  - Full-stack web app with database
  - Multi-service architecture with GUI

### **Images**
Prebuilt base container images to speed up builds.

- **Purpose:** Avoid rebuilding common layers every time
- **Characteristics:**
  - Optional but recommended for faster startup
  - Can include pre-installed tools and dependencies
  - Published to container registries (GHCR, Docker Hub)
- **Examples:**
  - Base Ubuntu with common dev tools
  - Node + Python polyglot image
  - GPU-enabled ML development image

---

## Airnub-Specific Concepts

### **Stack**
An opinionated Template flavor with a tested combination of services and tools.

- **What it is:** A Template that bundles multiple services into a cohesive development environment
- **Not a formal spec term:** The Dev Container specification doesn't define "Stack" - it's our organizational concept
- **Typical Stack Composition:**
  - Development container (Node + pnpm + Python + Deno)
  - Database services (Supabase/PostgreSQL)
  - Cache layer (Redis)
  - GUI provider (Webtop, noVNC, or Chrome)
  - Debugging tools (Chrome DevTools Protocol on port 9222)

**Examples in our catalog:**
- `templates/stack-nextjs-supabase-webtop/` - Full GUI with Webtop desktop
- `templates/stack-nextjs-supabase-novnc/` - Lightweight noVNC desktop

Each stack includes:
- `dockerComposeFile` defining all services
- Port labels (9222 CDP, 3001/6080 desktop, 6379 Redis)
- Chosen Features (Node, Supabase CLI, agent CLIs)

### **Meta Workspace**
A thin consumer repository that materializes Stack Templates.

- **What it is:** This repository - the one you're reading documentation for
- **Role:**
  - Fetches and materializes Templates from the catalog
  - Provides a `.code-workspace` for multi-root VS Code projects
  - Optionally auto-clones project repos on first open
  - Acts as the "workspace wrapper" around the catalog content

**Key Characteristics:**
- **Thin layer:** Doesn't contain Features/Templates/Images code (those live in the catalog)
- **Materialization:** Uses `scripts/sync-from-catalog.sh` to fetch catalog content
- **Multi-project:** Designed to work with multiple application repos simultaneously
- **Shared services:** Runs one Supabase + Redis instance for all projects (~70% resource savings)

**What NOT to do:**
- Don't add Features/Templates/Images code here (use the catalog)
- Don't commit cloned app repos (they're in `.gitignore`)
- Don't reference folders outside the repo root in the workspace file

### **Catalog**
The upstream repository containing reusable Templates, Features, and Images.

- **Location:** `airnub-labs/devcontainers-catalog` (separate repository)
- **Purpose:** Central source of truth for all reusable development environment components
- **Distribution:** Templates packaged as tarballs, accessed via GitHub releases or branches
- **Versioning:** Use `CATALOG_REF` to pin to specific tags/commits for reproducibility

---

## The Shared Services Model

A key innovation of this workspace is the shared services architecture:

### Why Share Services?

**Traditional Approach (each project has its own):**
```
Project A → Supabase instance (2GB RAM, 8 containers)
Project B → Supabase instance (2GB RAM, 8 containers)
Project C → Supabase instance (2GB RAM, 8 containers)
Total: 6GB RAM, 24 containers, port conflicts galore
```

**Shared Approach (this workspace):**
```
Project A ─┐
Project B ─┼→ One Supabase instance (2GB RAM, 8 containers)
Project C ─┘
Total: 2GB RAM, 8 containers, no conflicts
```

### Shared Services in This Workspace

1. **Supabase Stack** (configured in `supabase/config.toml`)
   - Single instance serves all projects
   - Projects switch by applying their migrations to shared DB
   - Centralized credentials managed via `.env.local` syncing

2. **Redis** (port 6379)
   - Single Redis instance available to all projects
   - Defined in `.devcontainer/docker-compose.yml`

3. **GUI Providers** (noVNC/Webtop/Chrome)
   - Shared browser-based desktop for testing
   - No need to run separate GUI per project

**Benefits:**
- ~70% reduction in resource usage
- Faster project switching (no service restart overhead)
- Simplified port management
- Centralized credential management

**Trade-offs:**
- Projects must coordinate schema migrations
- No schema isolation (projects share same database, different schemas)
- Not suitable for projects requiring incompatible Supabase versions

---

## Workspace Materialization Flow

Understanding how the workspace gets set up:

```
1. Developer clones meta workspace repo
   ↓
2. Run: TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh
   ↓
3. Script downloads catalog tarball
   ↓
4. Template extracted to .devcontainer/
   ↓
5. Open in VS Code / Codespaces
   ↓
6. Dev Container builds using materialized .devcontainer/
   ↓
7. postCreate hooks run (install tools, clone repos)
   ↓
8. postStart hooks run (start Supabase, sync env vars)
   ↓
9. Ready to develop!
```

### Key Configuration Points

| Variable | Purpose | Example |
|----------|---------|---------|
| `CATALOG_REF` | Catalog version to fetch | `main`, `v1.2.3`, commit SHA |
| `TEMPLATE` | Which stack to materialize | `stack-nextjs-supabase-webtop` |
| `WORKSPACE_ROOT` | Where cloned repos appear | `/airnub-labs` (this workspace) |

---

## Design Invariants

These are the guardrails for working with the meta workspace (from [AGENTS.md](../../AGENTS.md)):

### Invariants

1. **Keep `.devcontainer/` materialized from the catalog template**
   - Don't manually edit `.devcontainer/` content
   - Re-sync from catalog when updates are needed
   - Customizations go in the catalog, not here

2. **No secrets in repo**
   - Use Codespaces/Repository secrets for sensitive data
   - Keep `.env.local` files in `.gitignore`
   - Never commit credentials, tokens, or API keys

3. **Idempotent hooks**
   - `postCreate` and `postStart` must be safe to re-run
   - Scripts should detect existing state and skip if unnecessary
   - No destructive operations without confirmation

4. **Ports and sidecars must match the chosen stack README**
   - Each stack documents its port assignments
   - Don't change ports without updating stack documentation
   - Ensure no conflicts between services

---

## Quick Reference Table

| Term | Type | Where It Lives | Purpose |
|------|------|----------------|---------|
| **Feature** | Dev Container concept | Catalog repo | Install tooling |
| **Template** | Dev Container concept | Catalog repo | Complete environment config |
| **Image** | Dev Container concept | Container registry | Prebuilt base |
| **Stack** | Airnub concept | Catalog repo | Opinionated Template flavor |
| **Meta Workspace** | Airnub concept | This repo | Template consumer/wrapper |
| **Catalog** | Airnub concept | Separate repo | Template/Feature source |

---

## Common Misconceptions

### ❌ "This repo contains the dev environment code"
**✅ Correct:** This repo *consumes* environments from the catalog. The actual environment definitions live in `airnub-labs/devcontainers-catalog`.

### ❌ "I should edit .devcontainer/ directly"
**✅ Correct:** The `.devcontainer/` directory is materialized from the catalog. Edit the catalog Template, then re-sync.

### ❌ "Each project needs its own Supabase"
**✅ Correct:** Projects share one Supabase instance and switch by applying their migrations. This saves resources and speeds up switching.

### ❌ "Stack is an official Dev Container term"
**✅ Correct:** "Stack" is our organizational concept. The official spec has Features, Templates, and Images.

---

## Next Steps

Now that you understand the core concepts:

1. **For quick setup:** Follow the [Quick Start Guide](./quick-start.md)
2. **For Supabase operations:** Read [Supabase Operations](../guides/supabase-operations.md)
3. **For multi-repo workflows:** Review [Multi-Repo Workflow](../guides/multi-repo-workflow.md)
4. **For architecture details:** See [Architecture Overview](../architecture/overview.md)

---

**Related Documentation:**
- [Architecture Overview](../architecture/overview.md) - System design deep-dive
- [Troubleshooting](../reference/troubleshooting.md) - Common issues
- [Ports & Services Reference](../reference/ports-and-services.md) - Port assignments
- [Documentation Index](../index.md) - All documentation

**Last updated:** 2025-10-30
