# CLI Reference - `airnub` Command

The `airnub` CLI is the central command-line interface for managing projects, databases, and environment variables in the Airnub Meta Workspace.

---

## Overview

The `airnub` command provides a unified interface for:
- Switching between projects
- Managing Supabase database operations
- Syncing environment variables
- Inspecting workspace state

**Location:** `/airnub-labs/airnub` (automatically on PATH in Dev Container)

**Philosophy:** The CLI follows a consistent naming pattern:
- `db *` commands manage the shared Supabase stack
- `project *` commands manage project-specific operations
- Commands chain together for complete workflows

---

## Command Structure

```
airnub <category> <action> [options] [-- supabase-args]
```

**Categories:**
- `use` - Quick project switching (alias for `project use`)
- `db` - Database operations (Supabase stack)
- `project` - Project management

**Global Options:**
- `--help` - Show help for any command
- `--` - Pass remaining arguments to underlying Supabase CLI

---

## Quick Start Commands

### Switch to a Project

```bash
# Most common command - switch to project and apply migrations
airnub use ./million-dollar-maps

# Use with options
airnub use ./million-dollar-maps --skip-status
```

**What it does:**
1. Syncs Supabase credentials to project's `.env.local`
2. Applies project migrations with `supabase db push`
3. Shows `supabase status` output
4. Remembers selection in `.airnub-current-project`

---

## Project Commands

### `airnub project use`

Switch to a project and prepare it for development.

**Syntax:**
```bash
airnub project use [PROJECT_DIR] [OPTIONS]
```

**Arguments:**
- `PROJECT_DIR` - Path to project directory (optional, uses last project if omitted)

**Options:**
- `--skip-status` - Don't show Supabase status after switching
- `-- ARGS` - Pass additional arguments to `supabase db push`

**Examples:**
```bash
# Switch to project (absolute path)
airnub project use /airnub-labs/million-dollar-maps

# Switch to project (relative path)
airnub project use ./million-dollar-maps

# Reuse last project
airnub project use

# Skip status output for faster switching
airnub project use ./my-project --skip-status

# Pass additional flags to supabase db push
airnub project use ./my-project -- --debug
```

**What it does:**
1. Resolves project directory path
2. Calls `airnub db env sync` to refresh Supabase credentials
3. Calls `airnub project env sync` to update project's `.env.local`
4. Runs `supabase db push --local` to apply migrations
5. Displays `supabase status` (unless `--skip-status`)
6. Records selection in `.airnub-current-project`

---

### `airnub project current`

Show which project is currently selected.

**Syntax:**
```bash
airnub project current
```

**Output:**
```
Current project: /airnub-labs/million-dollar-maps
```

**Use case:** Check which project was last activated, useful when returning to workspace later.

---

### `airnub project setup`

Initialize a project's environment files.

**Syntax:**
```bash
airnub project setup [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Project directory (default: current project or `./supabase`)

**Examples:**
```bash
# Set up current project
airnub project setup

# Set up specific project
airnub project setup --project-dir ./million-dollar-maps
```

**What it does:**
1. Copies `.env.example` to `.env.local` if it doesn't exist
2. Appends new keys from `.env.example` without overwriting existing values
3. Syncs Supabase credentials to `.env.local`

**Use case:** First-time project setup or after adding new environment variables to `.env.example`.

---

### `airnub project clean`

Forget the remembered project selection.

**Syntax:**
```bash
airnub project clean
```

**What it does:**
- Removes `.airnub-current-project` file
- Next `airnub use` will require explicit project path

**Use case:** Reset project selection after switching contexts.

---

### `airnub project env sync`

Merge shared Supabase credentials into a project's `.env.local`.

**Syntax:**
```bash
airnub project env sync [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Project directory (default: current project)

**Examples:**
```bash
# Sync to current project
airnub project env sync

# Sync to specific project
airnub project env sync --project-dir ./million-dollar-maps
```

**What it does:**
1. Reads `supabase/.env.local` (shared credentials)
2. Merges into `project/.env.local`
3. Preserves project-specific environment variables
4. Only updates Supabase-related keys

**Use case:** Refresh project credentials after Supabase restart or when credentials change.

---

### `airnub project env diff`

Compare project's environment with shared Supabase credentials.

**Syntax:**
```bash
airnub project env diff [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Project directory (default: current project)

**Examples:**
```bash
# Compare current project
airnub project env diff

# Compare specific project
airnub project env diff --project-dir ./million-dollar-maps
```

**Output:**
Shows which variables would be added/updated if you ran `project env sync`.

**Use case:** Inspect credential differences before syncing.

---

### `airnub project env clean`

Remove a project's generated environment file.

**Syntax:**
```bash
airnub project env clean [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Project directory (default: current project)

**Examples:**
```bash
# Clean current project
airnub project env clean

# Clean specific project
airnub project env clean --project-dir ./million-dollar-maps
```

**⚠️ Warning:** This deletes the project's `.env.local` file. Use with caution.

**Use case:** Reset project environment to start fresh.

---

## Database Commands

### `airnub db apply`

Apply project migrations to the shared Supabase database.

**Syntax:**
```bash
airnub db apply [OPTIONS] [-- SUPABASE_ARGS]
```

**Options:**
- `--project-dir PATH` - Project with migrations (default: current project)
- `--project-env-file PATH` - Project's `.env.local` location
- `--project-ref NAME` - Project reference name
- `--skip-env-sync` - Don't sync credentials before applying
- `--ensure-env-sync` - Force credential sync before applying (default)
- `--status-only-env-sync` - Try status first, only start if needed
- `-- ARGS` - Pass to `supabase db push`

**Examples:**
```bash
# Apply migrations from current project
airnub db apply

# Apply from specific project
airnub db apply --project-dir ./million-dollar-maps

# Apply with custom env file
airnub db apply --project-env-file ./custom.env

# Skip credential sync (faster if already synced)
airnub db apply --skip-env-sync

# Pass flags to supabase db push
airnub db apply -- --debug
```

**What it does:**
1. Optionally syncs credentials (unless `--skip-env-sync`)
2. Runs `supabase db push --workdir PROJECT_DIR --local`
3. Migrations are applied to shared database

**Use case:** Deploy schema changes from your project to the shared Supabase instance.

---

### `airnub db reset`

Reset the shared Supabase database (destructive!).

**Syntax:**
```bash
airnub db reset [OPTIONS] [-- SUPABASE_ARGS]
```

**Options:**
- Same as `airnub db apply`

**Examples:**
```bash
# Reset database with current project's migrations
airnub db reset

# Reset with specific project
airnub db reset --project-dir ./million-dollar-maps

# Reset without confirmation (dangerous!)
airnub db reset -- -y
```

**⚠️ Warning:** This destroys all data in the shared database and reapplies migrations from scratch.

**What it does:**
1. Optionally syncs credentials
2. Runs `supabase db reset --workdir PROJECT_DIR --local`
3. Database is wiped and migrations reapplied

**Use case:** Start with a clean database state, useful for testing or recovering from bad migrations.

---

### `airnub db status`

Show Supabase stack status.

**Syntax:**
```bash
airnub db status [OPTIONS] [-- SUPABASE_ARGS]
```

**Options:**
- `--project-dir PATH` - Project directory for workdir context
- `-- ARGS` - Pass to `supabase status`

**Examples:**
```bash
# Show status
airnub db status

# Show status with specific project context
airnub db status --project-dir ./million-dollar-maps

# Show verbose output
airnub db status -- --debug
```

**Output:**
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
...
```

**Use case:** Verify Supabase is running and see service URLs.

---

### `airnub db env sync`

Refresh shared Supabase credentials.

**Syntax:**
```bash
airnub db env sync [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Supabase config directory (default: `./supabase`)
- `--env-file PATH` - Where to write credentials (default: `supabase/.env.local`)
- `--ensure-start` - Allow starting Supabase if not running
- `--status-only` - Only use `status`, never start Supabase

**Examples:**
```bash
# Sync credentials (start Supabase if needed)
airnub db env sync --ensure-start

# Sync without starting (fail if not running)
airnub db env sync --status-only

# Sync to custom location
airnub db env sync --env-file ./custom-supabase.env
```

**What it does:**
1. Runs `supabase status -o env` (or `supabase start -o env` with `--ensure-start`)
2. Captures output to `supabase/.env.local`
3. Credentials are ready for project sync

**Use case:** Refresh credentials after Supabase restart or when they've expired.

---

### `airnub db env diff`

Compare Supabase CLI output with stored credentials.

**Syntax:**
```bash
airnub db env diff [OPTIONS]
```

**Options:**
- `--project-dir PATH` - Supabase config directory
- `--env-file PATH` - Credentials file to compare

**Output:**
Shows which credentials have changed since last sync.

**Use case:** Check if credentials are stale before syncing.

---

### `airnub db env clean`

Remove the shared Supabase credentials file.

**Syntax:**
```bash
airnub db env clean [OPTIONS]
```

**Options:**
- `--env-file PATH` - File to remove (default: `supabase/.env.local`)

**Use case:** Force credential regeneration on next sync.

---

## Alias Commands

### `airnub use`

**Alias for:** `airnub project use`

The most commonly used command, provided as a top-level alias for convenience.

```bash
# These are equivalent:
airnub use ./million-dollar-maps
airnub project use ./million-dollar-maps
```

---

## Environment Variables

The CLI respects these environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `PROJECT_DIR` | Default project directory | Current project or `./supabase` |
| `PROJECT_ENV_FILE` | Project's `.env.local` location | `$PROJECT_DIR/.env.local` |
| `SUPABASE_PROJECT_REF` | Project reference name | Project directory name |
| `SKIP_SHARED_ENV_SYNC` | Skip credential sync if `1` | `0` |
| `SHARED_ENV_ENSURE_START` | Allow Supabase start if `1` | `0` |
| `WORKSPACE_ROOT` | Workspace root directory | `/airnub-labs` |

**Example:**
```bash
# Use environment variable to set project
PROJECT_DIR=./million-dollar-maps airnub db apply
```

---

## Compatibility with Legacy Scripts

The `airnub` CLI replaces legacy helper scripts:

### Old: `supabase/scripts/use-shared-supabase.sh`

```bash
# Old way
./supabase/scripts/use-shared-supabase.sh push

# New way
airnub db apply
```

**Equivalents:**
```bash
use-shared-supabase.sh push   → airnub db apply
use-shared-supabase.sh reset  → airnub db reset
use-shared-supabase.sh status → airnub db status
```

The legacy script still works (it delegates to `airnub`), but new scripts should use `airnub` directly.

---

## Common Workflows

### Workflow: First Time Project Setup

```bash
# 1. Clone project (if not auto-cloned)
cd /airnub-labs
git clone https://github.com/airnub-labs/my-project.git

# 2. Initialize environment
airnub project setup --project-dir ./my-project

# 3. Switch to project and apply migrations
airnub use ./my-project

# 4. Start dev server
cd my-project
pnpm dev
```

---

### Workflow: Switch Between Projects

```bash
# Working on project A
cd /airnub-labs/project-a
pnpm dev

# Switch to project B
# Stop project A's server first! (Ctrl+C)
cd /airnub-labs
airnub use ./project-b

cd project-b
pnpm dev
```

---

### Workflow: Update Credentials After Supabase Restart

```bash
# Supabase was restarted (new credentials generated)
airnub db env sync --ensure-start

# Sync to all projects that need it
airnub project env sync --project-dir ./project-a
airnub project env sync --project-dir ./project-b
```

---

### Workflow: Clean Database and Reapply Migrations

```bash
# Reset database (destructive!)
airnub db reset --project-dir ./my-project

# Verify schema is correct
airnub db status

# Seed data if needed
cd my-project
pnpm db:seed  # Or your project's seed script
```

---

## Troubleshooting

### Command Not Found: `airnub`

**Cause:** Not in Dev Container, or PATH not set up

**Solution:**
```bash
# Use absolute path
/airnub-labs/airnub use ./my-project

# Or add to PATH
export PATH="/airnub-labs:$PATH"
```

---

### Error: "No current project"

**Cause:** `.airnub-current-project` doesn't exist or is invalid

**Solution:**
```bash
# Explicitly specify project
airnub use ./million-dollar-maps

# Or check what's recorded
cat .airnub-current-project
```

---

### Error: "Supabase not running"

**Cause:** Supabase services aren't started

**Solution:**
```bash
# Start Supabase first
supabase start -o env

# Or use --ensure-start
airnub db env sync --ensure-start
airnub use ./my-project
```

---

### Credentials Not Syncing

**Cause:** Stale or corrupted credential files

**Solution:**
```bash
# Clean and regenerate
airnub db env clean
airnub db env sync --ensure-start

# Sync to project
airnub project env sync --project-dir ./my-project
```

---

## Advanced Usage

### Custom Supabase Arguments

Pass arguments directly to Supabase CLI:

```bash
# Debug mode
airnub db apply -- --debug

# Skip confirmation on reset
airnub db reset -- -y

# Verbose status
airnub db status -- -o json
```

---

### Scripting with `airnub`

```bash
#!/bin/bash
# Deploy migrations to all projects

PROJECTS=(
  ./project-a
  ./project-b
  ./project-c
)

for project in "${PROJECTS[@]}"; do
  echo "Deploying $project..."
  airnub db apply --project-dir "$project" || exit 1
done

echo "All projects deployed!"
```

---

### Environment Variable Override

```bash
# Use different env file for project
PROJECT_ENV_FILE=./custom.env airnub use ./my-project

# Skip credential sync for speed
SKIP_SHARED_ENV_SYNC=1 airnub db apply

# Force Supabase start if needed
SHARED_ENV_ENSURE_START=1 airnub db env sync
```

---

## Related Documentation

- **[Quick Start Guide](../getting-started/quick-start.md)** - Getting started with the workspace
- **[Shared Supabase Operations](../guides/supabase-operations.md)** - Detailed Supabase workflow
- **[Troubleshooting](./troubleshooting.md)** - Common issues and solutions
- **[Core Concepts](../getting-started/concepts.md)** - Understanding the shared services model

---

## Command Summary

### Quick Reference

| Command | Purpose |
|---------|---------|
| `airnub use PROJECT` | Switch to project, sync env, apply migrations |
| `airnub project current` | Show current project |
| `airnub project setup` | Initialize project `.env.local` |
| `airnub project env sync` | Merge Supabase creds to project |
| `airnub db apply` | Apply migrations |
| `airnub db reset` | Reset database (destructive) |
| `airnub db status` | Show Supabase status |
| `airnub db env sync` | Refresh Supabase credentials |

---

**Last updated:** 2025-10-30
