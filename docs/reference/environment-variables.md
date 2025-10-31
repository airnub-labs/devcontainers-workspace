# Environment Variables Reference

This document provides a comprehensive reference of all environment variables used in the Airnub Meta Workspace, including configuration for Dev Container setup, multi-repo cloning, Supabase operations, GUI providers, and CLI behavior.

> **⚠️ Customization Note:**
> The default values shown in this document use `airnub-labs` as the workspace name and organization. You can customize these defaults by setting the corresponding environment variables (e.g., `WORKSPACE_ROOT`, `WORKSPACE_STACK_NAME`, `CATALOG_REPO`) in your `.devcontainer/.env` file or devcontainer.json configuration.

---

## Quick Reference Table

| Category | Variable | Default | Purpose |
|----------|----------|---------|---------|
| **Workspace** | `WORKSPACE_ROOT` | `/airnub-labs` | Workspace root directory |
| **Workspace** | `WORKSPACE_CONTAINER_ROOT` | `/airnub-labs` | Container mount point |
| **Workspace** | `WORKSPACE_STACK_NAME` | `airnub-labs` | Compose project name |
| **Catalog** | `CATALOG_REF` | `main` | Catalog version to fetch |
| **Catalog** | `TEMPLATE` | (required) | Stack template name |
| **Catalog** | `CATALOG_REPO` | `airnub-labs/devcontainers-catalog` | Catalog repository |
| **Cloning** | `CLONE_WITH` | `auto` | Clone method (gh/ssh/https/https-pat) |
| **Cloning** | `ALLOW_WILDCARD` | `0` | Expand wildcard repos |
| **Supabase** | `PROJECT_DIR` | Current project | Project directory |
| **Supabase** | `SUPABASE_PROJECT_REF` | Directory name | Project reference |
| **GUI** | `GUI_PROVIDERS` | `novnc` | GUI providers to start |
| **GUI** | `GUI_CHROME_DEBUG` | `1` | Enable Chrome DevTools |

---

## Workspace Configuration

Variables that control the Dev Container workspace setup.

### `WORKSPACE_ROOT`

**Purpose:** Defines where project repositories are cloned within the container.

**Default:** `/airnub-labs` (overrides Dev Containers default of `/workspaces`)

**Used by:**
- Clone helper scripts
- airnub CLI
- Project detection

**Examples:**
```bash
# Use default
# Projects cloned to: /airnub-labs/project-name

# Custom location
export WORKSPACE_ROOT=/projects
# Projects cloned to: /projects/project-name
```

**Related:** This is set in `.devcontainer/.env` and applies to all scripts.

---

### `WORKSPACE_CONTAINER_ROOT`

**Purpose:** Changes the mount point where the repository appears inside the container.

**Default:** `/airnub-labs`

**Used by:**
- Docker Compose configuration
- Dev Container mounting

**Examples:**
```bash
# Default behavior
# Repository mounted at: /airnub-labs

# Custom mount point (set before container starts)
export WORKSPACE_CONTAINER_ROOT=/custom/path
```

**Note:** This must be set before the Dev Container starts. Changing it requires rebuilding the container.

---

### `WORKSPACE_STACK_NAME`

**Purpose:** Updates the Compose project name used by Docker Compose and downstream scripts.

**Default:** `airnub-labs`

**Used by:**
- `.devcontainer/docker-compose.yml`
- Supabase CLI (for stable project naming)

**Examples:**
```bash
# Default compose project name
# Containers named: airnub-labs_dev_1, airnub-labs_redis_1

# Custom project name
export WORKSPACE_STACK_NAME=my-workspace
# Containers named: my-workspace_dev_1, my-workspace_redis_1
```

**Impact:** Affects Docker network and volume names.

---

### `DEVCONTAINER_PROJECT_NAME`

**Purpose:** Overrides the project label written to logs.

**Default:** Value of `WORKSPACE_STACK_NAME`

**Used by:**
- Logging systems
- Container labels

**Examples:**
```bash
export DEVCONTAINER_PROJECT_NAME="Airnub Development Workspace"
```

---

## Catalog Materialization

Variables for syncing templates from the DevContainers catalog.

### `CATALOG_REF`

**Purpose:** Specifies which version of the catalog to fetch (git ref: branch, tag, or commit SHA).

**Default:** `main`

**Used by:**
- `scripts/sync-from-catalog.sh`

**Examples:**
```bash
# Use latest from main branch (default)
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Pin to specific tag (recommended for production)
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Use specific commit (for testing)
CATALOG_REF=abc123def456 TEMPLATE=stack-nextjs-supabase-novnc scripts/sync-from-catalog.sh

# Use feature branch
CATALOG_REF=feature/new-template TEMPLATE=experimental-stack scripts/sync-from-catalog.sh
```

**Best Practice:** Always pin `CATALOG_REF` to a tag or commit in production for reproducibility.

**Related:** See [Catalog Consumption Guide](../CATALOG-CONSUMPTION.md#reproducibility)

---

### `TEMPLATE`

**Purpose:** Specifies which template to materialize from the catalog.

**Default:** (none - **required**)

**Used by:**
- `scripts/sync-from-catalog.sh`

**Examples:**
```bash
# Webtop desktop variant
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# noVNC desktop variant
TEMPLATE=stack-nextjs-supabase-novnc scripts/sync-from-catalog.sh
```

**Available Templates:** Check the catalog repository for current templates.

---

### `CATALOG_REPO`

**Purpose:** Specifies the GitHub repository containing the catalog.

**Default:** `airnub-labs/devcontainers-catalog`

**Used by:**
- `scripts/sync-from-catalog.sh`

**Examples:**
```bash
# Use default
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Use fork or different catalog
CATALOG_REPO=your-org/custom-catalog \
TEMPLATE=your-custom-stack \
scripts/sync-from-catalog.sh
```

**Use Case:** Organizations maintaining their own catalog fork.

---

## Multi-Repo Cloning

Variables for controlling automatic repository cloning.

### `CLONE_WITH`

**Purpose:** Forces a specific authentication method for cloning repositories.

**Default:** `auto` (tries methods in order: gh → ssh → https-pat → https)

**Options:**
- `auto` - Auto-detect best method
- `gh` - Use GitHub CLI
- `ssh` - Use SSH keys
- `https` - HTTPS (unauthenticated, public repos only)
- `https-pat` - HTTPS with Personal Access Token

**Used by:**
- `.devcontainer/scripts/clone-from-devcontainer-repos.sh`

**Examples:**
```bash
# Auto-detect (default)
CLONE_WITH=auto bash scripts/clone-from-devcontainer-repos.sh

# Force SSH
CLONE_WITH=ssh bash scripts/clone-from-devcontainer-repos.sh

# Force GitHub CLI
CLONE_WITH=gh bash scripts/clone-from-devcontainer-repos.sh

# Force HTTPS with PAT
CLONE_WITH=https-pat GH_MULTI_REPO_PAT=$MY_TOKEN bash scripts/clone-from-devcontainer-repos.sh
```

---

### `GH_MULTI_REPO_PAT`

**Purpose:** Personal Access Token for HTTPS cloning (used only during clone, then removed from remote URL).

**Default:** (unset)

**Used by:**
- Clone helper (when `CLONE_WITH=https-pat`)

**Examples:**
```bash
# Set inline (token not persisted)
GH_MULTI_REPO_PAT=ghp_xxx... CLONE_WITH=https-pat bash scripts/clone-from-devcontainer-repos.sh

# Or from environment
export GH_MULTI_REPO_PAT=ghp_xxx...
CLONE_WITH=https-pat bash scripts/clone-from-devcontainer-repos.sh
```

**Security:** Token is used only during clone; the remote URL is reset to clean HTTPS after cloning.

---

### `ALLOW_WILDCARD`

**Purpose:** Controls whether wildcard permissions (e.g., `owner/*`) are expanded into concrete repository lists.

**Default:** `0` (disabled)

**Options:**
- `0` - Only clone explicitly listed repos
- `1` - Expand wildcards using `gh repo list`

**Used by:**
- Clone helper script

**Examples:**
```bash
# Default: only clone explicitly listed repos
ALLOW_WILDCARD=0 bash scripts/clone-from-devcontainer-repos.sh

# Expand airnub-labs/* to clone all org repos
ALLOW_WILDCARD=1 bash scripts/clone-from-devcontainer-repos.sh
```

**⚠️ Warning:** Setting to `1` with broad wildcards may clone many repositories.

---

### `CLONE_ON_START`

**Purpose:** Controls whether the clone helper re-runs on `postStart` (every container restart).

**Default:** `false`

**Options:**
- `false` - Only clone on `postCreate` (first time)
- `true` - Re-run clone helper on every start

**Used by:**
- `.devcontainer/scripts/post-start.sh`

**Examples:**
```bash
# Default: clone only on first start
CLONE_ON_START=false

# Re-clone on every start (fetches updates)
CLONE_ON_START=true
```

**Use Case:** Set to `true` to automatically fetch repo updates on container restart.

---

### `DEVCONTAINER_FILE`

**Purpose:** Specifies the path to `devcontainer.json` for reading repository permissions.

**Default:** `.devcontainer/devcontainer.json`

**Used by:**
- Clone helper script

**Examples:**
```bash
# Use default
bash scripts/clone-from-devcontainer-repos.sh

# Custom location
DEVCONTAINER_FILE=./custom/devcontainer.json bash scripts/clone-from-devcontainer-repos.sh
```

---

### `WORKSPACE_FILE`

**Purpose:** Path to `.code-workspace` file (used for hints/documentation, not filtering).

**Default:** (auto-discovered `*.code-workspace` in root)

**Used by:**
- Clone helper (informational only)

**Examples:**
```bash
# Auto-discover (default)
bash scripts/clone-from-devcontainer-repos.sh

# Explicit path
WORKSPACE_FILE=./airnub-labs.code-workspace bash scripts/clone-from-devcontainer-repos.sh
```

---

## Supabase & Database

Variables for controlling Supabase operations and the `airnub` CLI.

### `PROJECT_DIR`

**Purpose:** Default project directory for Supabase operations.

**Default:** Current project (from `.airnub-current-project`) or `./supabase`

**Used by:**
- `airnub` CLI commands

**Examples:**
```bash
# Use remembered project
airnub db apply

# Override with environment variable
PROJECT_DIR=./million-dollar-maps airnub db apply

# Or use command-line option
airnub db apply --project-dir ./million-dollar-maps
```

---

### `PROJECT_ENV_FILE`

**Purpose:** Location of project's `.env.local` file.

**Default:** `$PROJECT_DIR/.env.local`

**Used by:**
- `airnub project env` commands

**Examples:**
```bash
# Use default location
airnub project env sync

# Custom env file
PROJECT_ENV_FILE=./custom.env airnub project env sync
```

---

### `SUPABASE_PROJECT_REF`

**Purpose:** Project reference name for Supabase operations.

**Default:** Project directory name (basename of `PROJECT_DIR`)

**Used by:**
- `airnub` CLI
- Supabase CLI invocations

**Examples:**
```bash
# Inferred from directory
cd million-dollar-maps
# Project ref: "million-dollar-maps"

# Override
SUPABASE_PROJECT_REF=my-custom-ref airnub db apply
```

---

### `SKIP_SHARED_ENV_SYNC`

**Purpose:** Skip credential synchronization during database operations.

**Default:** `0` (sync enabled)

**Options:**
- `0` - Always sync credentials before operations
- `1` - Skip credential sync (faster if already synced)

**Used by:**
- `airnub db` commands

**Examples:**
```bash
# Default: sync credentials
airnub db apply

# Skip sync for speed
SKIP_SHARED_ENV_SYNC=1 airnub db apply
```

**Use Case:** Skip sync if you know credentials are fresh to speed up operations.

---

### `SHARED_ENV_ENSURE_START`

**Purpose:** Allow `airnub db env sync` to start Supabase if not running.

**Default:** `0` (don't auto-start)

**Options:**
- `0` - Only use `status`, fail if not running
- `1` - Use `start` if `status` fails

**Used by:**
- `airnub db env sync`

**Examples:**
```bash
# Only check status
SHARED_ENV_ENSURE_START=0 airnub db env sync

# Start Supabase if needed
SHARED_ENV_ENSURE_START=1 airnub db env sync
# Or use --ensure-start flag
airnub db env sync --ensure-start
```

---

### `SUPABASE_INCLUDE`

**Purpose:** Comma-separated list of Supabase services to run.

**Default:** All services (no exclusions)

**Used by:**
- `.devcontainer/scripts/supabase-up.sh`

**Examples:**
```bash
# Run all services (default)
supabase start

# Only essential services
SUPABASE_INCLUDE=db,auth,rest supabase start

# Minimal setup
SUPABASE_INCLUDE=db supabase start
```

**Services:** `db`, `auth`, `rest`, `storage`, `realtime`, `analytics`, `inbucket`

**Note:** The script translates this into exclusion list (`-x`) for `supabase start`.

---

## GUI Providers

Variables for controlling browser-based desktop environments.

### `GUI_PROVIDERS`

**Purpose:** Comma-separated list of GUI providers to start.

**Default:** `novnc`

**Options:**
- `novnc` - Lightweight VNC desktop
- `webtop` - Full HTTPS desktop with audio
- `chrome` - Standalone Chrome browser
- `all` - Start all GUI providers

**Used by:**
- `.devcontainer/scripts/select-gui-profiles.sh`
- Docker Compose profiles

**Examples:**
```bash
# Default: noVNC only
GUI_PROVIDERS=novnc

# Webtop desktop
GUI_PROVIDERS=webtop

# Multiple providers
GUI_PROVIDERS=webtop,chrome

# All providers (distinct ports)
GUI_PROVIDERS=all
```

**Impact:** Determines which Docker Compose profiles are activated.

---

### `GUI_CHROME_DEBUG`

**Purpose:** Toggles Chrome DevTools Protocol remote debugging ports.

**Default:** `1` (enabled)

**Options:**
- `1` - Enable CDP on ports 9222, 9223, 9224
- `0` - Disable CDP listeners

**Used by:**
- GUI provider startup scripts

**Examples:**
```bash
# Enable debugging (default)
GUI_CHROME_DEBUG=1

# Disable for security/performance
GUI_CHROME_DEBUG=0
```

**Impact:** When enabled, Chrome/Chromium starts with `--remote-debugging-port`.

---

### noVNC Configuration

#### `GUI_NOVNC_HTTP_PORT`

**Default:** `6080`

**Purpose:** HTTP port for noVNC desktop.

**Example:**
```bash
GUI_NOVNC_HTTP_PORT=6080
```

#### `GUI_NOVNC_DEVTOOLS_PORT`

**Default:** `9222`

**Purpose:** Chrome DevTools Protocol port for noVNC.

---

### Webtop Configuration

#### `GUI_WEBTOP_HTTPS_PORT`

**Default:** `3001`

**Purpose:** HTTPS port for Webtop desktop.

#### `GUI_WEBTOP_DEVTOOLS_PORT`

**Default:** `9223`

**Purpose:** Chrome DevTools Protocol port for Webtop.

#### `WEBTOP_USER`

**Default:** `abc`

**Purpose:** Basic auth username for Webtop.

**Example:**
```bash
WEBTOP_USER=myusername
WEBTOP_PASSWORD=mypassword
```

#### `WEBTOP_PASSWORD`

**Default:** (generated or set in `.env`)

**Purpose:** Basic auth password for Webtop.

**Security:** Keep private, especially in Codespaces.

#### `WEBTOP_AUDIO`

**Default:** `1` (enabled)

**Options:**
- `1` - Enable WebRTC audio streaming
- `0` - Disable audio

**Example:**
```bash
WEBTOP_AUDIO=1  # Enable audio over HTTPS
```

---

### Chrome Provider Configuration

#### `GUI_CHROME_HTTPS_PORT`

**Default:** `3002`

**Purpose:** HTTPS port for Chrome provider.

#### `GUI_CHROME_DEVTOOLS_PORT`

**Default:** `9224`

**Purpose:** Chrome DevTools Protocol port.

#### `CHROME_USER` / `CHROME_PASSWORD`

**Purpose:** Basic auth credentials for Chrome provider.

**Default:** Reuses `WEBTOP_USER` / `WEBTOP_PASSWORD`

---

## GitHub & Authentication

### `GHCR_USER`

**Purpose:** GitHub username for GHCR authentication (Codespaces only).

**Default:** (unset)

**Used by:**
- Codespaces preflight login

**Example:**
```bash
# Add as Codespaces repository secret
GHCR_USER=your-github-username
```

---

### `GHCR_PAT`

**Purpose:** Personal Access Token for GHCR pulls (Codespaces only).

**Default:** (unset)

**Used by:**
- Codespaces preflight login

**Example:**
```bash
# Add as Codespaces repository secret (with Packages: Read permission)
GHCR_PAT=ghp_xxx...
```

**Security:** Should be fine-grained PAT with Packages: Read, SSO enabled.

---

## Advanced & Internal

### `COMPOSE_PROJECT_NAME`

**Purpose:** Docker Compose project name (typically set by workspace scripts).

**Default:** `${WORKSPACE_STACK_NAME}-supabase`

**Used by:**
- Supabase Compose operations

**Example:**
```bash
# Automatically set by scripts
COMPOSE_PROJECT_NAME=airnub-labs-supabase supabase status
```

---

## Environment File Locations

### Where to Set Variables

| Variable Category | Set In | Scope |
|------------------|--------|-------|
| Workspace-wide | `.devcontainer/.env` | All containers & scripts |
| Codespaces secrets | GitHub UI | Codespaces environment |
| Project-specific | `project/.env.local` | Single project |
| Shared Supabase | `supabase/.env.local` | Supabase credentials |
| One-time/Testing | Command line | Single command |

**Example `.devcontainer/.env`:**
```bash
# Workspace configuration
WORKSPACE_ROOT=/airnub-labs
WORKSPACE_STACK_NAME=airnub-labs

# GUI configuration
GUI_PROVIDERS=webtop
WEBTOP_USER=myuser
WEBTOP_PASSWORD=mypassword

# Catalog defaults
CATALOG_REF=v1.2.3
```

---

## Quick Reference by Use Case

### Setting Up Private Image Pulls
```bash
# Codespaces: Set repository secrets
GHCR_USER=your-username
GHCR_PAT=ghp_xxx...

# Local: Login once
docker login ghcr.io -u your-username
```

### Customizing Clone Behavior
```bash
# In .devcontainer/.env
CLONE_WITH=ssh
ALLOW_WILDCARD=0
CLONE_ON_START=false
```

### Changing GUI Provider
```bash
# In .devcontainer/.env
GUI_PROVIDERS=webtop
WEBTOP_USER=admin
WEBTOP_PASSWORD=secure-password
GUI_CHROME_DEBUG=1
```

### Pinning Catalog Version
```bash
# In sync script or .env
CATALOG_REF=v1.2.3
TEMPLATE=stack-nextjs-supabase-webtop
```

### Speeding Up airnub Commands
```bash
# Skip credential sync when unnecessary
SKIP_SHARED_ENV_SYNC=1 airnub db apply

# Or disable in .env
SKIP_SHARED_ENV_SYNC=1
```

---

## Related Documentation

- **[Quick Start Guide](../getting-started/quick-start.md)** - Setting up your environment
- **[CLI Reference](./cli-reference.md)** - Using environment variables with airnub
- **[Multi-Repo Workflow](../guides/multi-repo-workflow.md)** - Clone configuration
- **[GUI Desktop Providers](../guides/gui-desktops.md)** - GUI configuration
- **[Catalog Consumption](../CATALOG-CONSUMPTION.md)** - Template materialization

---

**Last updated:** 2025-10-30
