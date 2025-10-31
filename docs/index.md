# Airnub DevContainers Workspace Documentation

Welcome to the Airnub Meta Workspace documentation. This workspace provides a sophisticated DevContainer environment that materializes pre-built development environments from a centralized catalog, enabling multi-project development with shared services.

## Quick Navigation

### 🚀 Getting Started

New to the workspace? Start here:

- **[Quick Start Guide](./getting-started/quick-start.md)** - 5-minute setup for first-time users
- **[Core Concepts](./getting-started/concepts.md)** - Understanding the system (Features, Templates, Stacks, Catalog)
- **[Main README](../README.md)** - Repository overview and quick reference
- **[AGENTS.md](../AGENTS.md)** - Design invariants and guardrails

### 📚 User Guides

Step-by-step guides for common tasks:

- **[Supabase Operations](./guides/supabase-operations.md)** - Working with the shared Supabase stack, running migrations, using the `airnub` CLI
- **[Multi-Repo Workflow](./guides/multi-repo-workflow.md)** - How the workspace clones and manages multiple project repositories
- **[GUI Desktop Providers](./guides/gui-desktops.md)** - Configuring browser-based desktops (noVNC, Webtop, Chrome)
- **[Catalog Consumption](./CATALOG-CONSUMPTION.md)** - Syncing templates from the DevContainers catalog

### 💡 Examples

Real-world workflow examples:

- **[Setting Up a New Project](./examples/setting-up-new-project.md)** - Complete workflow from clone to running dev server
- **[Switching Between Projects](./examples/switching-projects.md)** - Managing multiple projects with shared database
- **[Running Migrations](./examples/running-migrations.md)** - Creating, applying, and troubleshooting database migrations
- **[Debugging with GUI](./examples/debugging-with-gui.md)** - Using browser-based desktops for visual debugging and testing

### 🔍 Reference

Technical specifications and troubleshooting:

- **[CLI Reference](./reference/cli-reference.md)** - Complete `airnub` command documentation
- **[Environment Variables](./reference/environment-variables.md)** - Comprehensive variable reference and configuration
- **[Ports & Services](./reference/ports-and-services.md)** - Port assignments and service configuration
- **[Troubleshooting Guide](./reference/troubleshooting.md)** - Common issues and solutions
- **[Workspace Architecture](./workspace-architecture.md)** - High-level role and responsibilities (brief)

### 🏗️ Architecture & Development

Deep-dives for contributors and advanced users:

- **[Architecture Overview](./architecture/overview.md)** - Complete system architecture and design
- **[Container Architecture](./architecture/container-layers.md)** - Understanding the outer Dev Container and inner Docker daemon
- **[Development Roadmap](./development/roadmap.md)** - Roadmap for spec-compliant packaging

---

## Documentation by Audience

### For First-Time Users

1. Start with the [Quick Start Guide](./getting-started/quick-start.md) for step-by-step setup
2. Read [Core Concepts](./getting-started/concepts.md) to understand the system
3. Learn about [Supabase Operations](./guides/supabase-operations.md) to work with the database
4. Check [GUI Desktop Providers](./guides/gui-desktops.md) if you need browser-based desktops

### For Daily Development

- Use the [CLI Reference](./reference/cli-reference.md) for `airnub` command documentation
- Browse [Examples](./examples/) for common workflow patterns
- Use the [Supabase Operations](./guides/supabase-operations.md) guide for database workflows
- Refer to [Troubleshooting](./reference/troubleshooting.md) when things go wrong
- Review [Multi-Repo Workflow](./guides/multi-repo-workflow.md) when adding new projects

### For Contributors & Advanced Users

- Understand the [Architecture Overview](./architecture/overview.md) for system design
- Read [Container Architecture](./architecture/container-layers.md) for container details
- Review [Development Roadmap](./development/roadmap.md) for the roadmap
- Check [AGENTS.md](../AGENTS.md) for design invariants

---

## Key Concepts

### What is a Meta Workspace?

A thin consumer of catalog **Templates** that:
- Materializes `.devcontainer/` from the catalog
- Provides a `.code-workspace` for multi-root VS Code projects
- Optionally clones app repos into the workspace
- Shares services (Supabase, Redis) across multiple projects

### The Stack

- **Features** → Install tooling (Supabase CLI, Node, CUDA, etc.) - idempotent, no services
- **Templates** → Ship ready-to-use `.devcontainer/` payloads (can be multi-container via Compose)
- **Images** → Prebuilt bases to speed builds
- **Stack** → An opinionated Template flavor in the catalog
- **Meta Workspace** → This repo (consumer of catalog templates)

### Shared Services Model

This workspace runs:
- **One Supabase instance** shared across all projects (~70% resource savings)
- **One Redis instance** available to all projects
- **GUI providers** (noVNC/Webtop/Chrome) for browser-based development

---

## Quick Reference

### Common Ports

| Service | Port | Notes |
|---------|------|-------|
| Supabase API | 54321 | REST/Realtime |
| Supabase Postgres | 54322 | Database access |
| Supabase Studio | 54323 | Web UI |
| Redis | 6379 | Shared cache |
| noVNC Desktop | 6080 | Browser-based desktop |
| Webtop Desktop | 3001 | HTTPS desktop |
| Chrome DevTools | 9222 | Remote debugging |

### Essential Commands

```bash
# Sync from catalog
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Work with Supabase
airnub use ./my-project              # Switch to project, sync env, apply migrations
airnub db status                     # Check Supabase status
airnub project setup                 # Initialize project .env.local

# Manual Supabase operations
supabase start -o env                # Start shared stack
supabase db push --workdir ./my-project --local
```

---

## Need Help?

- **Common issues?** Check the [Troubleshooting Guide](./reference/troubleshooting.md)
- **Understanding the architecture?** Read [Container Architecture](./architecture/container-layers.md)
- **Contributing?** Review [AGENTS.md](../AGENTS.md) for design invariants

---

**Last updated:** 2025-10-31
