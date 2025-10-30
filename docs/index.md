# Airnub DevContainers Workspace Documentation

Welcome to the Airnub Meta Workspace documentation. This workspace provides a sophisticated DevContainer environment that materializes pre-built development environments from a centralized catalog, enabling multi-project development with shared services.

## Quick Navigation

### 🚀 Getting Started

New to the workspace? Start here:

- **[Main README](../README.md)** - Overview, quick start, and GHCR authentication
- **[AGENTS.md](../AGENTS.md)** - Design invariants and guardrails

### 📚 User Guides

Step-by-step guides for common tasks:

- **[Shared Supabase Operations](./shared-supabase.md)** - Working with the shared Supabase stack, running migrations, using the `airnub` CLI
- **[Multi-Repo Workflow](./clone-strategy.md)** - How the workspace clones and manages multiple project repositories
- **[GUI Desktop Providers](./gui-providers.md)** - Configuring browser-based desktops (noVNC, Webtop, Chrome)
- **[Catalog Consumption](./CATALOG-CONSUMPTION.md)** - Syncing templates from the DevContainers catalog

### 🔍 Reference

Technical specifications and troubleshooting:

- **[Troubleshooting Guide](./reference/troubleshooting.md)** - Common issues and solutions
- **[Workspace Architecture](./workspace-architecture.md)** - High-level role and responsibilities

### 🏗️ Architecture & Development

Deep-dives for contributors and advanced users:

- **[Docker Container Architecture](./docker-containers.md)** - Understanding the outer Dev Container and inner Docker daemon
- **[DevContainer Spec Alignment](./devcontainer-spec-alignment.md)** - Roadmap for spec-compliant packaging
- **[Post-Create Review](./postcreate-review.md)** - Summary of initialization activities

---

## Documentation by Audience

### For First-Time Users

1. Read the [Main README](../README.md) to understand what this workspace is
2. Follow the GHCR authentication setup if using private images
3. Learn about [Shared Supabase Operations](./shared-supabase.md) to work with the database
4. Check [GUI Desktop Providers](./gui-providers.md) if you need browser-based desktops

### For Daily Development

- Use the [Shared Supabase Operations](./shared-supabase.md) guide for the `airnub` CLI commands
- Refer to [Troubleshooting](./reference/troubleshooting.md) when things go wrong
- Review [Multi-Repo Workflow](./clone-strategy.md) when adding new projects

### For Contributors & Advanced Users

- Understand the [Docker Container Architecture](./docker-containers.md)
- Review [DevContainer Spec Alignment](./devcontainer-spec-alignment.md) for the roadmap
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
- **Understanding the architecture?** Read [Docker Container Architecture](./docker-containers.md)
- **Contributing?** Review [AGENTS.md](../AGENTS.md) for design invariants

---

**Last updated:** 2025-10-30
