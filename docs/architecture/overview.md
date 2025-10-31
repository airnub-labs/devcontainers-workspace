# Architecture Overview

This document provides a comprehensive overview of the Airnub Meta Workspace architecture, explaining how all the pieces fit together to create a powerful multi-project development environment.

> **⚠️ Customization Note:**
> This document uses `airnub-labs` as an example organization and `$WORKSPACE_ROOT` (default: `/airnub-labs`) as the workspace directory. Customize these values for your own setup.

---

## What is the Meta Workspace?

The Meta Workspace is a **thin consumer** of Dev Container **Templates** (also called "stacks" in our terminology). It serves as a wrapper that:

1. **Materializes** `.devcontainer/` configuration from a centralized catalog
2. **Provides** a `.code-workspace` for multi-root VS Code projects
3. **Optionally clones** project repositories on first open
4. **Shares services** (Supabase, Redis) across multiple projects

### Key Principle: Separation of Concerns

```
┌─────────────────────────────────────────────────────────┐
│  Catalog Repository (upstream)                          │
│  - Features (install scripts)                           │
│  - Templates (environment configs)                      │
│  - Images (prebuilt containers)                         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ Materialization (sync script)
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Meta Workspace (this repository)                       │
│  - Materialized .devcontainer/                          │
│  - .code-workspace file                                 │
│  - Cloned project repos (gitignored)                    │
│  - Shared service orchestration                         │
└─────────────────────────────────────────────────────────┘
```

---

## The Meta Workspace Role

### What It Does

✅ **Materializes Templates** from the catalog into `.devcontainer/`
- Uses `scripts/sync-from-catalog.sh` to fetch tarball
- Extracts Template content to replace `.devcontainer/`
- Allows version pinning via `CATALOG_REF` environment variable

✅ **Provides Multi-Root Workspace Configuration**
- Ships `.code-workspace` for VS Code
- Defines which project folders appear in the explorer
- Configures workspace-level settings and extensions

✅ **Clones Project Repositories** (optional)
- Automatically clones repos listed in `devcontainer.json` permissions
- Places clones in workspace root (gitignored via pattern)
- Idempotent: safe to re-run, only fetches updates

✅ **Orchestrates Shared Services**
- Runs single Supabase instance for all projects
- Provides Redis sidecar accessible to all projects
- Manages GUI desktop providers (noVNC, Webtop, Chrome)
- Handles environment variable syncing across projects

### What It Doesn't Do

❌ **Define Features/Templates/Images**
- Those live in the catalog repository
- Don't add dev environment code here

❌ **Commit Cloned Repos**
- Cloned projects are gitignored
- Each project maintains its own git history

❌ **Provide Project Isolation**
- Shared Supabase means shared database
- Projects must coordinate schema migrations

---

## Catalog Materialization Flow

Understanding how the workspace gets its `.devcontainer/`:

```
1. Developer sets environment variables
   CATALOG_REF=v1.2.3
   TEMPLATE=stack-nextjs-supabase-webtop

2. Run sync script
   scripts/sync-from-catalog.sh

3. Script downloads catalog tarball
   https://github.com/airnub-labs/devcontainers-catalog/archive/$CATALOG_REF.tar.gz

4. Extract Template directory
   .template/templates/$TEMPLATE/* → .devcontainer/

5. Cleanup
   Remove temporary files
   Template is now materialized

6. Open in VS Code/Codespaces
   Uses materialized .devcontainer/
   Builds containers
   Runs lifecycle hooks
```

### Reproducibility

Pin `CATALOG_REF` to a specific tag or commit SHA:

```bash
# Pinned to tag
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Pinned to commit
CATALOG_REF=abc123def TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Latest (not recommended for production)
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh
```

Stacks may also publish `stack.lock.json` to pin Feature versions and Image digests.

---

## Shared Services Architecture

A key differentiator of this workspace is the shared services model.

### Traditional Multi-Project Setup

```
Project A (.devcontainer/)
  ├─ Supabase (8 containers, 2GB RAM)
  ├─ Redis (1 container, 100MB RAM)
  └─ GUI (1-3 containers, 500MB RAM)

Project B (.devcontainer/)
  ├─ Supabase (8 containers, 2GB RAM)
  ├─ Redis (1 container, 100MB RAM)
  └─ GUI (1-3 containers, 500MB RAM)

Project C (.devcontainer/)
  ├─ Supabase (8 containers, 2GB RAM)
  ├─ Redis (1 container, 100MB RAM)
  └─ GUI (1-3 containers, 500MB RAM)

Total: 24 Supabase containers, 3 Redis, 3-9 GUI
Resource usage: ~6-8GB RAM
```

### Meta Workspace Shared Setup

```
Meta Workspace (.devcontainer/)
  ├─ Dev Container (main)
  ├─ Supabase (8 containers, 2GB RAM) ◄─┐
  ├─ Redis (1 container, 100MB RAM)   ◄─┼─ Shared
  └─ GUI (1-3 containers, 500MB RAM)  ◄─┘

Project A (migrations/) ─┐
Project B (migrations/) ─┼─► Applies to shared Supabase
Project C (migrations/) ─┘

Total: 8 Supabase containers, 1 Redis, 1-3 GUI
Resource usage: ~2.5GB RAM
```

**Resource Savings: ~70%**

### How Projects Share Services

1. **Supabase Database**
   - All projects connect to same Postgres instance
   - Projects apply their migrations to shared DB
   - Different schemas or tables per project (must coordinate)
   - Single set of credentials synced to all projects

2. **Redis**
   - Shared cache available on port 6379
   - Projects use namespacing/prefixes to avoid key conflicts
   - Defined in `.devcontainer/docker-compose.yml`

3. **GUI Providers**
   - One desktop for testing all projects
   - Switch projects without restarting GUI
   - Browser state persists across project switches

### Trade-offs

**Benefits:**
- ✅ ~70% reduction in resource usage
- ✅ Faster project switching (no service restart)
- ✅ Simplified port management (no conflicts)
- ✅ Centralized credential management

**Limitations:**
- ⚠️ No database schema isolation between projects
- ⚠️ Projects must coordinate migrations
- ⚠️ Can't run projects requiring different Supabase versions
- ⚠️ One project's bad migration can affect others

---

## Container Architecture

The workspace uses a layered container architecture:

```
┌──────────────────────────────────────────────────────────┐
│  Host Machine (your computer or Codespace VM)            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Outer Dev Container (VS Code attached)            │  │
│  │  - User: vscode                                     │  │
│  │  - Workspace mounted: /airnub-labs                 │  │
│  │  - Tools: Node, Python, Deno, Supabase CLI        │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Inner Docker Daemon (DinD)                  │  │  │
│  │  │  - Runs Supabase containers                  │  │  │
│  │  │  - Manages service networking                │  │  │
│  │  │  - Volume: dind-data (persisted)            │  │  │
│  │  │                                              │  │  │
│  │  │  Supabase Containers:                        │  │  │
│  │  │  ├─ postgres                                 │  │  │
│  │  │  ├─ kong (API gateway)                       │  │  │
│  │  │  ├─ auth (GoTrue)                            │  │  │
│  │  │  ├─ rest (PostgREST)                         │  │  │
│  │  │  ├─ storage                                   │  │  │
│  │  │  ├─ realtime                                  │  │  │
│  │  │  ├─ analytics                                 │  │  │
│  │  │  └─ inbucket (email)                          │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  Compose Sidecars (siblings to Dev Container):     │  │
│  │  ├─ Redis                                          │  │
│  │  └─ GUI (noVNC/Webtop/Chrome)                     │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**See [Container Architecture](./container-layers.md) for detailed explanation.**

---

## Design Invariants

These guardrails ensure the workspace remains maintainable and secure:

### 1. Keep `.devcontainer/` Materialized from Catalog

**✅ DO:**
- Sync from catalog when you need updates
- Edit the catalog Template, then re-sync here

**❌ DON'T:**
- Manually edit `.devcontainer/` files directly
- Add custom configurations that should be in the catalog

**Why:** The `.devcontainer/` directory is a materialized artifact. Manual edits will be lost on next sync.

### 2. No Secrets in Repository

**✅ DO:**
- Use Codespaces/Repository secrets for sensitive data
- Keep `.env.local` files in `.gitignore`
- Store credentials in environment variables

**❌ DON'T:**
- Commit `.env.local` files
- Hard-code API keys, tokens, or passwords
- Check in Supabase credentials

**Why:** Secrets in version control create security vulnerabilities and are difficult to rotate.

### 3. Idempotent Lifecycle Hooks

**✅ DO:**
- Make `postCreate` and `postStart` safe to re-run
- Check for existing state before taking action
- Use conditional logic (if not exists, then create)

**❌ DON'T:**
- Assume scripts run only once
- Perform destructive operations without checks
- Fail on "already exists" errors

**Why:** Dev Containers may rebuild or restart, triggering hooks multiple times.

### 4. Ports Match Stack Documentation

**✅ DO:**
- Use standard ports defined in stack README
- Document any custom port assignments
- Check for conflicts before adding new services

**❌ DON'T:**
- Change port assignments without updating docs
- Use conflicting ports between services
- Assume ports are available without checking

**Why:** Standardized ports enable the shared services model and prevent conflicts.

---

## Multi-Project Workflow

How multiple projects coexist in the workspace:

### Directory Structure

```
/airnub-labs/                        # Workspace root (WORKSPACE_ROOT)
├── .devcontainer/                   # Materialized from catalog
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   └── scripts/
├── .code-workspace                  # VS Code multi-root workspace
├── supabase/                        # Shared Supabase config
│   ├── config.toml                  # Supabase configuration
│   ├── .env.local                   # Shared credentials (gitignored)
│   └── docker/                      # Supabase runtime data
├── million-dollar-maps/             # Cloned project A (gitignored)
│   ├── .env.local                   # Project-specific env (gitignored)
│   ├── supabase/
│   │   └── migrations/              # Project A migrations
│   └── ...                          # Project A code
├── another-project/                 # Cloned project B (gitignored)
│   ├── .env.local
│   ├── supabase/
│   │   └── migrations/
│   └── ...
└── scripts/                         # Meta workspace scripts
    └── sync-from-catalog.sh
```

### Switching Between Projects

Using the `airnub` CLI:

```bash
# Switch to project A
airnub use ./million-dollar-maps
# → Syncs credentials, applies migrations, shows status

# Switch to project B
airnub use ./another-project
# → Syncs credentials, applies migrations, shows status

# Check current project
airnub project current
```

**What happens during switch:**
1. Shared Supabase credentials synced to project `.env.local`
2. Project migrations applied to shared database
3. Supabase status displayed
4. Project remembered for future `airnub use` calls

---

## Lifecycle Hooks

Dev Containers execute hooks at specific times:

### onCreate (devcontainer.json)
**When:** First time container is created
**Purpose:** One-time setup tasks
**Examples:**
- Install global packages
- Set up git configuration
- Initialize tool chains

### postCreateCommand
**When:** After onCreate, still during initial creation
**Purpose:** Project-specific initialization
**Examples:**
- Clone project repositories
- Install dependencies
- Set up database structure

**In this workspace:**
```bash
.devcontainer/scripts/post-create.sh
├─ Install Chrome/Chromium
├─ Configure browser policies
├─ Clone repos from devcontainer.json permissions
└─ Set up initial project selection
```

### postStartCommand
**When:** Every time the container starts
**Purpose:** Start services, refresh state
**Examples:**
- Start databases
- Launch background services
- Sync environment variables

**In this workspace:**
```bash
.devcontainer/scripts/post-start.sh
├─ Start Supabase (if AUTOSTART_SUPABASE=true)
├─ Sync shared credentials
├─ Set up noVNC landing page
└─ Initialize audio bridge
```

---

## Configuration Points

Key environment variables and files:

| Variable | Purpose | Default | Set Where |
|----------|---------|---------|-----------|
| `CATALOG_REF` | Catalog version | `main` | Shell/script |
| `TEMPLATE` | Stack template to use | (required) | Shell/script |
| `WORKSPACE_ROOT` | Where repos are cloned | `/airnub-labs` | `.devcontainer/.env` |
| `GUI_PROVIDERS` | Which GUI(s) to start | `novnc` | `.devcontainer/.env` |
| `SUPABASE_INCLUDE` | Supabase services to run | All | `.devcontainer/.env` |

**Configuration files:**
- `.devcontainer/devcontainer.json` - Dev Container settings
- `.devcontainer/docker-compose.yml` - Service definitions
- `.devcontainer/.env` - Environment variables (gitignored)
- `.code-workspace` - VS Code workspace definition
- `supabase/config.toml` - Supabase configuration

---

## Security Model

### Secrets Management

1. **Never commit secrets**
   - `.env.local` files are gitignored
   - Use repository/Codespaces secrets for CI/CD

2. **Credential hierarchy**
   - Shared Supabase credentials in `supabase/.env.local`
   - Project-specific overrides in `project/.env.local`
   - Merged during `airnub use` or manual sync

3. **GHCR Authentication**
   - Fine-grained PAT with Packages:Read permission
   - SSO enabled for organization
   - Stored in OS keychain or Codespaces secrets

### Network Security

1. **Port visibility**
   - All ports private by default in Codespaces
   - No external access without authentication

2. **Service isolation**
   - Services communicate via Docker network
   - Not exposed to host except via port forwarding

3. **Browser policies**
   - Managed Chrome policies restrict navigation
   - Only localhost and GitHub/Codespaces domains allowed
   - Extensions disabled by default

---

## Resource Management

### Recommended Resources

**Minimum:**
- 4GB RAM
- 2 CPU cores
- 20GB disk space

**Recommended:**
- 8GB RAM
- 4 CPU cores
- 50GB disk space

### Resource Consumption

Typical usage with all services running:

| Component | RAM | CPU | Notes |
|-----------|-----|-----|-------|
| Dev Container | 500MB | 10% | Base workspace |
| Supabase Stack | 2GB | 30% | All services |
| Redis | 100MB | 5% | Cache |
| GUI (noVNC) | 500MB | 10% | Lightweight option |
| GUI (Webtop) | 1GB | 15% | Full desktop |
| **Total (noVNC)** | **~3GB** | **~55%** | |
| **Total (Webtop)** | **~3.5GB** | **~60%** | |

### Optimization Tips

1. **Stop unused services**
   ```bash
   supabase stop              # When not using database
   docker compose stop novnc  # When not using GUI
   ```

2. **Clean Docker cache**
   ```bash
   docker system prune -af
   docker volume prune -f
   ```

3. **Limit Supabase services**
   ```bash
   # Only run essential services
   SUPABASE_INCLUDE=db,auth,rest supabase start
   ```

---

## Related Documentation

- **[Core Concepts](../getting-started/concepts.md)** - Taxonomy and terminology
- **[Container Architecture](./container-layers.md)** - Detailed container structure
- **[Supabase Operations](../guides/supabase-operations.md)** - Using the shared database
- **[Ports & Services Reference](../reference/ports-and-services.md)** - Complete port listings
- **[Troubleshooting](../reference/troubleshooting.md)** - Common issues and solutions

---

**Last updated:** 2025-10-30
