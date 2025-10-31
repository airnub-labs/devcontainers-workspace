# Example: Switching Between Projects

This example demonstrates how to switch between multiple projects that share the same Supabase database in the Airnub Meta Workspace.

---

## Scenario

You're working on two projects:
- `project-a` - An e-commerce frontend
- `project-b` - An admin dashboard

Both share the same Supabase database, but have different migrations and environment configurations.

---

## Prerequisites

- Both projects are cloned to `/airnub-labs/`
- Supabase is running (`supabase status` shows active)
- Both projects have `supabase/migrations/` directories

---

## Understanding Shared Database Implications

**Key concept:** All projects in the workspace share the **same Supabase database instance**.

**What this means:**
- Schema changes from one project affect all projects
- Switching projects applies that project's migrations to the shared database
- Be careful with destructive migrations
- Coordinate schema changes across teams

**Migration strategy:**
- Use additive migrations when possible (add columns, not remove)
- Coordinate breaking changes with all project teams
- Consider using separate databases for isolated development

---

## Step-by-Step: Basic Switch

### 1. Check Current Project

```bash
# See which project is currently active
airnub project current
```

**Expected output:**
```
Current project: /airnub-labs/project-a
```

---

### 2. Switch to Another Project

```bash
# Switch to project-b
cd /airnub-labs
airnub use ./project-b
```

**What happens:**
1. Syncs Supabase credentials to `project-b/.env.local`
2. Applies `project-b/supabase/migrations/` to shared database
3. Shows Supabase status
4. Records `project-b` as current project

**Expected output:**
```
Switching to project: /airnub-labs/project-b
✓ Synced Supabase credentials
✓ Applied migrations

Started supabase local development setup.

         API URL: http://127.0.0.1:54321
...
```

---

### 3. Verify Environment Variables

```bash
# Check that project-b's .env.local was updated
cat project-b/.env.local | grep SUPABASE
```

**Expected output:**
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

### 4. Verify Schema Changes

If `project-b` has migrations that `project-a` didn't, check that they were applied:

**Option A: Supabase Studio**
```bash
# Open http://localhost:54323
# Navigate to: Table Editor
# Look for new tables/columns from project-b
```

**Option B: psql**
```bash
# Connect to database
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres

# List all tables
\dt public.*

# Check specific table
\d public.new_table_from_project_b

# Exit
\q
```

---

### 5. Start Development Server

```bash
cd project-b
pnpm install  # If dependencies not installed yet
pnpm dev
```

**Expected output:**
```
> project-b@1.0.0 dev
> next dev

ready - started server on 0.0.0.0:3000, url: http://localhost:3000
```

---

## Step-by-Step: Quick Switch Without Status

If you're frequently switching and want faster execution:

```bash
# Skip status output for speed
airnub use ./project-b --skip-status
```

**What this saves:**
- Skips `supabase status` command at the end
- Reduces output verbosity
- Credentials still synced, migrations still applied

---

## Advanced: Switch and Run in One Command

```bash
# Switch and immediately start dev server
cd /airnub-labs
airnub use ./project-b && cd project-b && pnpm dev
```

---

## Handling Migration Conflicts

### Scenario: Conflicting Migrations

**Problem:** `project-a` added a column `email` to `users` table. `project-b` also added a column `email` to `users` table with different type.

**Symptoms:**
```
Error applying migration: column "email" already exists
```

**Solution:**

1. **Check what's already in the database:**
   ```bash
   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres
   \d public.users
   \q
   ```

2. **Coordinate with other project teams:**
   - Decide on canonical schema
   - Update conflicting migration to match

3. **Option A: Modify migration (before applying)**
   ```bash
   # Edit the conflicting migration
   code project-b/supabase/migrations/*_add_email.sql

   # Change to ALTER instead of ADD
   ALTER TABLE public.users ALTER COLUMN email TYPE text;
   ```

4. **Option B: Reset and reapply (destructive!)**
   ```bash
   # Reset entire database
   airnub db reset --project-dir ./project-b

   # This will:
   # - Drop all tables
   # - Reapply ALL migrations from project-b
   # - ⚠️ ALL DATA WILL BE LOST
   ```

---

## Handling Different Dependencies

### Scenario: Projects Use Different Node Versions

**Problem:** `project-a` uses Node 18, `project-b` uses Node 20

**Solution:**

**Option A: Use nvm (if installed)**
```bash
# Switch to project-b
cd /airnub-labs/project-b

# Check required version
cat .nvmrc  # or package.json "engines"

# Switch Node version
nvm use 20

# Install dependencies
pnpm install

# Run dev server
pnpm dev
```

**Option B: Use Dev Container feature**
```bash
# Update .devcontainer/devcontainer.json to include:
"features": {
  "ghcr.io/devcontainers/features/node:1": {
    "version": "20"
  }
}

# Rebuild container
# Command Palette → "Dev Containers: Rebuild Container"
```

---

## Best Practices

### 1. Stop Previous Dev Server

**Always stop the previous project's dev server before switching:**

```bash
# In project-a terminal
# Press Ctrl+C to stop dev server

# Then switch
cd /airnub-labs
airnub use ./project-b
cd project-b
pnpm dev
```

**Why:** Prevents port conflicts (usually port 3000)

---

### 2. Check Migration Status Before Switching

```bash
# See what migrations are pending
cd project-b
supabase migration list

# Review migration files
ls -la supabase/migrations/
```

---

### 3. Use Descriptive Migration Names

```bash
# ❌ Bad (unclear what this does)
supabase migration new update_users

# ✅ Good (clear, specific)
supabase migration new add_users_email_column
```

---

### 4. Document Schema Dependencies

Create a `SCHEMA.md` in each project:

```markdown
# Schema Dependencies

## Tables Used
- `users` - Requires columns: id, email, created_at
- `posts` - Requires columns: id, user_id, title, content

## Shared Schema Assumptions
- `users.email` is TEXT type
- `users.id` is UUID with default gen_random_uuid()
```

---

## Workflow Comparison

### Sequential Development (One Project at a Time)

```bash
# Morning: Work on project-a
airnub use ./project-a
cd project-a && pnpm dev

# Afternoon: Switch to project-b
# (Stop project-a dev server first!)
cd /airnub-labs
airnub use ./project-b
cd project-b && pnpm dev
```

**Pros:**
- Simple, clear context
- No mental overhead

**Cons:**
- Switching takes ~10 seconds
- Need to remember to stop previous server

---

### Parallel Development (Multiple Terminals)

```bash
# Terminal 1: project-a on port 3000
airnub use ./project-a
cd project-a && pnpm dev

# Terminal 2: project-b on port 3001
airnub use ./project-b
cd project-b && PORT=3001 pnpm dev
```

**Pros:**
- No switching delay
- Both servers running

**Cons:**
- Both projects see same database state
- Need to manage different ports
- More resource usage

---

## Troubleshooting

### Error: "No such file or directory"

**Symptom:**
```
Error: Project directory not found: ./project-b
```

**Cause:** Project not cloned yet

**Solution:**
```bash
cd /airnub-labs
git clone https://github.com/your-org/project-b.git
airnub use ./project-b
```

---

### Error: "Migration already applied"

**Symptom:**
```
Error: Migration 20231030120000_add_users.sql already applied
```

**Cause:** Database already has this migration from another project

**Solution:**
```bash
# Check migration history
supabase migration list

# If schema is correct, no action needed
# If schema is wrong, see "Handling Migration Conflicts" above
```

---

### Port 3000 Still in Use

**Symptom:**
```
Error: Port 3000 is already in use
```

**Cause:** Previous dev server still running

**Solution:**
```bash
# Find process using port 3000
lsof -ti:3000

# Kill it
kill $(lsof -ti:3000)

# Or use different port
PORT=3001 pnpm dev
```

---

### Environment Variables Not Loading

**Symptom:** App can't connect to Supabase after switching

**Cause:** `.env.local` not synced or server not restarted

**Solution:**
```bash
# Re-sync credentials
airnub project env sync --project-dir ./project-b

# Restart dev server
# Press Ctrl+C in dev server terminal
pnpm dev
```

---

## Related Examples

- [Setting Up a New Project](./setting-up-new-project.md)
- [Running Migrations](./running-migrations.md)
- [Debugging with GUI](./debugging-with-gui.md)

## Related Documentation

- [Quick Start Guide](../getting-started/quick-start.md)
- [CLI Reference](../reference/cli-reference.md)
- [Supabase Operations](../guides/supabase-operations.md)
- [Troubleshooting](../reference/troubleshooting.md)

---

**Last updated:** 2025-10-31
