# Example: Setting Up a New Project

This example walks through setting up a new project in the Airnub Meta Workspace from scratch.

> **⚠️ Customization Note:**
> This example uses `$WORKSPACE_ROOT` as the workspace root directory. By default, this is `/airnub-labs`, but you can customize it by setting the `WORKSPACE_ROOT` environment variable. Replace `my-awesome-app` with your actual project name and repository URL.

---

## Scenario

You want to start working on a new project called `my-awesome-app` that uses Supabase for the backend.

---

## Prerequisites

- Workspace is open in Dev Container
- Supabase is running (`supabase start -o env`)

---

## Step-by-Step

### 1. Clone the Project Repository

```bash
# Navigate to workspace root
cd $WORKSPACE_ROOT

# Clone your project
git clone https://github.com/your-org/my-awesome-app.git
cd my-awesome-app
```

**Expected output:**
```
Cloning into 'my-awesome-app'...
remote: Enumerating objects: 123, done.
remote: Counting objects: 100% (123/123), done.
...
```

---

### 2. Initialize Project Environment

Use `airnub project setup` to create `.env.local` from `.env.example`:

```bash
cd $WORKSPACE_ROOT
airnub project setup --project-dir ./my-awesome-app
```

**What this does:**
1. Copies `.env.example` to `.env.local` if it doesn't exist
2. Appends new keys from example without overwriting existing values
3. Syncs Supabase credentials from shared stack

**Expected output:**
```
Setting up project: $WORKSPACE_ROOT/my-awesome-app
✓ Created .env.local from .env.example
✓ Synced Supabase credentials
Project setup complete!
```

---

### 3. Review and Customize Environment Variables

```bash
# Check what was generated
cat my-awesome-app/.env.local
```

**Example `.env.local`:**
```bash
# Your project-specific variables
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres
API_URL=http://localhost:3000

# Supabase credentials (synced automatically)
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Customize as needed:**
```bash
# Edit with VS Code
code my-awesome-app/.env.local

# Or use your preferred editor
nano my-awesome-app/.env.local
```

---

### 4. Create Initial Migration (if needed)

If your project doesn't have migrations yet:

```bash
cd my-awesome-app

# Create migrations directory
mkdir -p supabase/migrations

# Create your first migration
supabase migration new init_schema

# Edit the migration file
code supabase/migrations/*_init_schema.sql
```

**Example migration (`supabase/migrations/20231030120000_init_schema.sql`):**
```sql
-- Create users table
create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.users enable row level security;

-- Create policy
create policy "Users can read own data"
  on public.users
  for select
  using (auth.uid() = id);
```

---

### 5. Apply Migrations to Shared Supabase

```bash
# Return to workspace root
cd $WORKSPACE_ROOT

# Use airnub to switch to this project and apply migrations
airnub use ./my-awesome-app
```

**What this does:**
1. Syncs credentials to project's `.env.local`
2. Applies migrations with `supabase db push --local`
3. Shows Supabase status
4. Remembers this project as current

**Expected output:**
```
Switching to project: $WORKSPACE_ROOT/my-awesome-app
✓ Synced Supabase credentials
✓ Applied migrations

Started supabase local development setup.

         API URL: http://127.0.0.1:54321
...
```

---

### 6. Verify Database Schema

Check that your tables were created:

**Option A: Supabase Studio (GUI)**
```bash
# Open in browser: http://localhost:54323
# Navigate to: Table Editor
# You should see your new tables
```

**Option B: psql (CLI)**
```bash
# Connect to database
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres

# List tables
\dt public.*

# View table schema
\d public.users

# Exit
\q
```

---

### 7. Install Project Dependencies

```bash
cd my-awesome-app

# For Node/npm projects
npm install

# For pnpm projects
pnpm install

# For Python projects
pip install -r requirements.txt
```

---

### 8. Start Development Server

```bash
# Still in my-awesome-app directory

# For Next.js
npm run dev
# or
pnpm dev

# For Python/Flask
python app.py

# For other frameworks, follow their docs
```

**Expected output:**
```
> my-awesome-app@0.1.0 dev
> next dev

ready - started server on 0.0.0.0:3000, url: http://localhost:3000
```

---

### 9. Access Your Application

**In VS Code:**
1. Open the **Ports** panel
2. Port 3000 should appear automatically
3. Click the globe icon 🌐 to open in browser

**In Codespaces:**
- URL: `https://<workspace>-3000.<region>.app.github.dev`

**Test the connection:**
```bash
# In terminal
curl http://localhost:3000
```

---

### 10. Add Project to VS Code Workspace (Optional)

Edit `.code-workspace` to include your new project:

```bash
code airnub-labs.code-workspace
```

**Add to `folders` array:**
```json
{
  "folders": [
    { "path": ".devcontainer" },
    { "path": "my-awesome-app" }
  ],
  "settings": {}
}
```

**Reload VS Code:**
- Command Palette → "Developer: Reload Window"

---

## Verification Checklist

- [ ] Project cloned to `$WORKSPACE_ROOT/my-awesome-app`
- [ ] `.env.local` created with Supabase credentials
- [ ] Migrations applied successfully
- [ ] Tables visible in Supabase Studio
- [ ] Dependencies installed
- [ ] Dev server running on port 3000
- [ ] Application accessible in browser
- [ ] Project added to VS Code workspace (optional)

---

## Next Steps

- **Make code changes:** Edit your project files
- **Add more migrations:** `supabase migration new your_migration_name`
- **Test API calls:** Use your app to interact with Supabase
- **Debug:** Use Chrome DevTools, browser console, or server logs

---

## Troubleshooting

### Port 3000 Already in Use

```bash
# Find what's using port 3000
lsof -ti:3000

# Kill the process
kill $(lsof -ti:3000)

# Or use different port
PORT=3001 npm run dev
```

### Migrations Fail

```bash
# Check Supabase is running
supabase status

# If not running
supabase start -o env

# Retry
airnub db apply --project-dir ./my-awesome-app
```

### Environment Variables Not Loading

```bash
# Re-sync credentials
airnub project env sync --project-dir ./my-awesome-app

# Verify .env.local exists and has values
cat my-awesome-app/.env.local

# Restart dev server to pick up changes
```

---

## Related Examples

- [Switching Between Projects](./switching-projects.md)
- [Running Migrations](./running-migrations.md)
- [Debugging with GUI](./debugging-with-gui.md)

## Related Documentation

- [Quick Start Guide](../getting-started/quick-start.md)
- [CLI Reference](../reference/cli-reference.md)
- [Supabase Operations](../guides/supabase-operations.md)
- [Troubleshooting](../reference/troubleshooting.md)

---

**Last updated:** 2025-10-30
