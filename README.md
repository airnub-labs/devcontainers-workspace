# Airnub Meta Workspace

A **thin consumer** of the [Airnub DevContainers Catalog](https://github.com/airnub-labs/devcontainers-catalog). This workspace materializes Dev Container Templates into `.devcontainer/`, provides a multi-root `.code-workspace`, and optionally auto-clones project repos on first open.

**📚 [Complete Documentation](docs/index.md)** | **🚀 [Quick Start](docs/getting-started/quick-start.md)** | **🔍 [Troubleshooting](docs/reference/troubleshooting.md)**

---

## What is This?

This meta workspace enables **multi-project development with shared services**:
- **Shared Supabase** instance across all projects (~70% resource savings)
- **Shared Redis** cache
- **Browser-based GUI** desktops (noVNC/Webtop)
- **Auto-cloning** of project repositories
- **Centralized** environment management

See [Core Concepts](docs/getting-started/concepts.md) for terminology and architecture.

---

## Quick Start

### 1. Open in Container

**Codespaces:**
- Click **Code** → **Codespaces** → **Create codespace**
- Wait for container to build (~3-5 minutes first time)

**VS Code Local:**
- Install Dev Containers extension
- Clone this repo and open in VS Code
- Click **Reopen in Container**

### 2. Authenticate to GHCR (if using private images)

See [Quick Start Guide - GHCR Authentication](docs/getting-started/quick-start.md#step-2-authenticate-to-ghcr-if-using-private-images) for detailed instructions.

**Quick version:**
```bash
docker login ghcr.io -u YOUR_USERNAME
# Paste your PAT when prompted
```

### 3. Start Supabase

```bash
supabase start -o env
```

### 4. Work with a Project

```bash
# Switch to your project (auto-syncs credentials, applies migrations)
airnub use ./your-project

# Or start from scratch
cd /airnub-labs
git clone https://github.com/your-org/your-project.git
airnub use ./your-project
```

---

## Essential Commands

```bash
# Sync template from catalog
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Supabase operations
supabase start -o env              # Start shared stack
airnub use ./project-name          # Switch project + apply migrations
airnub db status                   # Check Supabase status

# Access services
# Supabase Studio: http://localhost:54323
# noVNC Desktop: http://localhost:6080
```

---

## Documentation

- **[Quick Start Guide](docs/getting-started/quick-start.md)** - Step-by-step tutorial
- **[Core Concepts](docs/getting-started/concepts.md)** - Understanding the system
- **[CLI Reference](docs/reference/cli-reference.md)** - Complete `airnub` command docs
- **[Supabase Operations](docs/guides/supabase-operations.md)** - Database workflows
- **[Troubleshooting](docs/reference/troubleshooting.md)** - Common issues
- **[Documentation Index](docs/index.md)** - All documentation

---

## Key Features

- **📦 Template Materialization** - Sync from centralized catalog
- **🗄️ Shared Supabase** - One instance for all projects
- **🔄 Multi-Repo** - Auto-clone configured repositories
- **🖥️ GUI Desktops** - Browser-based noVNC/Webtop
- **🔧 CLI Tools** - `airnub` command for easy management
- **♻️ Reproducible** - Pin catalog versions for consistency

---

**Getting Help:** See [Documentation Index](docs/index.md) | Report issues on GitHub
