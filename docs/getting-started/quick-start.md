# Quick Start Guide

Welcome! This guide will help you set up and start using the Airnub Meta Workspace in under 10 minutes.

> **⚠️ Customization Note:**
> This guide uses `airnub-labs` as the example organization name and `$WORKSPACE_ROOT` (default: `/airnub-labs`) as the workspace directory. Replace these with your own organization and workspace names where applicable.

---

## Prerequisites

Before you begin, make sure you have:

- [ ] **VS Code** installed (or access to GitHub Codespaces)
- [ ] **Docker** installed and running (for local development)
- [ ] **Git** installed
- [ ] **GitHub account** with access to the workspace repository

**Optional but recommended:**
- [ ] GitHub CLI (`gh`) installed for easier authentication

---

## Step 1: Choose Your Environment

You can use this workspace in two ways:

### Option A: GitHub Codespaces (Recommended for First-Time Users)

**Pros:** No local setup, works in browser, resources managed by GitHub
**Cons:** Requires GitHub Codespaces quota

1. Go to the repository on GitHub
2. Click the green **Code** button
3. Select **Codespaces** tab
4. Click **Create codespace on main**
5. Wait for the container to build (3-5 minutes first time)
6. Skip to [Step 3: Authenticate to GHCR](#step-3-authenticate-to-ghcr-if-using-private-images)

### Option B: VS Code Dev Containers (Local)

**Pros:** Full control, no quota limits, works offline
**Cons:** Requires Docker, uses local resources

1. Install the **Dev Containers** extension in VS Code
2. Clone the repository:
   ```bash
   git clone https://github.com/airnub-labs/devcontainers-workspace.git
   cd devcontainers-workspace
   ```
3. Open in VS Code:
   ```bash
   code .
   ```
4. When prompted, click **Reopen in Container**
   - Or use Command Palette: `Dev Containers: Reopen in Container`
5. Wait for the container to build (3-5 minutes first time)
6. Continue to Step 2 below

---

## Step 2: Authenticate to GHCR (If Using Private Images)

If the devcontainer image is private (hosted on GitHub Container Registry), you need to authenticate before Docker can pull it.

### A) Create a Fine-Grained Personal Access Token

1. **Go to GitHub Settings:**
   - Click your profile → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
   - Click **Generate new token**

2. **Configure the token:**
   - **Token name:** `devcontainers-ghcr-read` (or any descriptive name)
   - **Resource owner:** Select `airnub-labs` (your organization)
   - **Repository access:** Choose **Only select repositories**
     - Select: `devcontainers-catalog` (or whichever repo publishes images)
   - **Permissions:**
     - **Repository permissions:**
       - Contents: **Read-only** (required for repo association)
     - **Account permissions:**
       - Packages: **Read** ✅ (this is the key for GHCR pulls)

3. **Generate and enable SSO:**
   - Click **Generate token**
   - On the token page, click **Enable SSO** for `airnub-labs`
   - **Copy the token** (you won't see it again!)

### B) Login to GHCR (One-Time Setup)

**For local development:**

```bash
# Logout first to clear any cached credentials
docker logout ghcr.io || true

# Login with your token
read -s GHCR_PAT && echo "$GHCR_PAT" | docker login ghcr.io -u "YOUR-GITHUB-USERNAME" --password-stdin
# Paste your token when prompted (nothing will be echoed)
```

After this, Docker can pull images without environment variables.

**For Codespaces:**

1. Go to the workspace repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Codespaces**
3. Add repository secrets:
   - `GHCR_USER` = your GitHub username
   - `GHCR_PAT` = the fine-grained token you created

The workspace will automatically login on start.

---

## Step 3: Understand the Workspace

Once your container is running, you're inside a powerful development environment:

### What's Included?

- **Development tools:** Node.js, pnpm, Python 3.12, Deno
- **Databases:** Supabase (PostgreSQL + Auth + Storage + Realtime)
- **Cache:** Redis
- **GUI:** Browser-based desktop (noVNC or Webtop)
- **Debugging:** Chrome DevTools Protocol support
- **CLI:** `airnub` command for managing projects

### Directory Structure

```
$WORKSPACE_ROOT/                 # Workspace root (default: /airnub-labs)
├── .devcontainer/               # Dev container configuration
├── supabase/                    # Shared Supabase configuration
├── scripts/                     # Workspace scripts
├── docs/                        # Documentation (you are here!)
└── <cloned-projects>/           # Your project repos (auto-cloned)
```

---

## Step 4: Start the Shared Supabase Stack

The workspace uses a **shared Supabase instance** for all projects. Start it once:

```bash
# Start Supabase and generate credentials
supabase start -o env
```

**Expected output:**
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
     GraphQL URL: http://127.0.0.1:54321/graphql/v1
  S3 Storage URL: http://127.0.0.1:54321/storage/v1/s3
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
    Inbucket URL: http://127.0.0.1:54324
...
```

**What this does:**
- Starts 8 Supabase containers (Postgres, Auth, Storage, etc.)
- Generates API keys and credentials
- Writes credentials to `supabase/.env.local`
- Makes services available on fixed ports

**💡 Tip:** Open Supabase Studio at [http://localhost:54323](http://localhost:54323) to explore the database visually.

---

## Step 5: Work with a Project

### If Projects Auto-Cloned

If your workspace auto-cloned project repositories during setup:

```bash
# List available projects
ls -d */

# Switch to a project
airnub use ./million-dollar-maps
```

**What `airnub use` does:**
1. Syncs Supabase credentials to project's `.env.local`
2. Applies project's migrations to shared database
3. Shows Supabase status
4. Remembers this project for next time

### If You Need to Clone a Project Manually

```bash
# Clone a project
cd $WORKSPACE_ROOT
git clone https://github.com/your-org/your-project.git

# Switch to it
airnub use ./your-project
```

---

## Step 6: Access the GUI Desktop (Optional)

The workspace includes a browser-based desktop for testing visual applications:

### For noVNC (Default)

1. In VS Code, open the **Ports** panel
2. Find port **6080**
3. Click the globe icon to open in browser
4. Desktop should appear automatically

**Codespaces URL pattern:**
```
https://<workspace>-6080.<region>.codespaces-preview.app
```

### For Webtop (If Configured)

1. Open port **3001** (HTTPS)
2. Login with credentials from `.devcontainer/.env`:
   - Username: Value of `WEBTOP_USER`
   - Password: Value of `WEBTOP_PASSWORD`

**💡 Tip:** Use the desktop for visual testing, browser automation, or running Playwright tests.

---

## Step 7: Start Developing

You're ready to code! Here's a typical workflow:

### Run Your Application

```bash
# Navigate to your project
cd million-dollar-maps

# Install dependencies (if not already done)
pnpm install

# Start development server
pnpm dev
```

**Forward the port:**
- Open VS Code **Ports** panel
- Port 3000 (or your app's port) should appear automatically
- Click the globe icon to open your app in browser

### Make Database Changes

```bash
# Create a new migration
supabase migration new add_users_table

# Edit the migration file in supabase/migrations/
# Then apply it:
airnub db apply
```

### Check Supabase Status

```bash
# Quick status check
airnub db status

# Or use Supabase CLI directly
supabase status
```

---

## Common First-Time Tasks

### Task: View Supabase Studio

**What:** Web UI for managing your database

**How:**
1. Open port **54323** in browser
2. Explore tables, run SQL queries, manage auth users

**URL:** [http://localhost:54323](http://localhost:54323)

---

### Task: Test Email Flows

**What:** Local email inbox for testing

**How:**
1. Open port **54324** in browser
2. Trigger an email in your app (e.g., password reset)
3. View captured email in Inbucket

**URL:** [http://localhost:54324](http://localhost:54324)

---

### Task: Switch Between Projects

**Scenario:** You have multiple projects that share the Supabase database

**How:**
```bash
# Switch to project A
airnub use ./project-a

# Work on project A...
# Then switch to project B
airnub use ./project-b
```

**What happens:**
- Project B's migrations are applied
- Project B's credentials are synced
- You can now run project B's dev server

**⚠️ Note:** Projects share the same database. Schema changes from one project affect others.

---

### Task: Update the Workspace Template

**What:** Fetch latest template from the catalog

**How:**
```bash
# Sync latest template
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Or with specific version
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Rebuild the container
# Command Palette → "Dev Containers: Rebuild Container"
```

**See:** [Catalog Consumption Guide](../CATALOG-CONSUMPTION.md)

---

## Troubleshooting

### Problem: "Port already in use"

**Solution:**
```bash
# Check what's using the port
lsof -i :54321

# Stop Supabase
supabase stop

# Restart
supabase start -o env
```

**See:** [Troubleshooting Guide - Port Conflicts](../reference/troubleshooting.md#port-conflicts)

---

### Problem: "Cannot connect to Supabase"

**Solution:**
```bash
# Check if Supabase is running
supabase status

# If not running, start it
supabase start -o env

# Sync credentials to your project
cd your-project
airnub project env sync
```

**See:** [Troubleshooting Guide - Supabase Issues](../reference/troubleshooting.md#supabase-issues)

---

### Problem: "Authentication failed" (GHCR)

**Solution:**
1. Verify your PAT has Packages:Read permission
2. Ensure SSO is enabled for your organization
3. Re-login:
   ```bash
   docker logout ghcr.io
   echo "$YOUR_PAT" | docker login ghcr.io -u YOUR_USERNAME --password-stdin
   ```

**See:** [Troubleshooting Guide - GHCR Authentication](../reference/troubleshooting.md#ghcr-authentication-failures)

---

## Next Steps

Now that you have the basics, explore more:

### Learn Core Concepts
Read [Core Concepts](./concepts.md) to understand:
- The difference between Features, Templates, and Stacks
- How the shared services model works
- The catalog materialization process

### Master the CLI
See [CLI Reference](../reference/cli-reference.md) for:
- Complete `airnub` command documentation
- Advanced workflows
- Environment variable management

### Work with Multiple Repos
Read [Multi-Repo Workflow](../guides/multi-repo-workflow.md) to learn:
- How repositories are auto-cloned
- Configuring which repos to clone
- Managing permissions

### Understand the Architecture
See [Architecture Overview](../architecture/overview.md) for:
- System design deep-dive
- Container architecture
- Resource management

### Explore All Guides
Visit [Documentation Index](../index.md) for the complete docs.

---

## Quick Reference

### Essential Commands

```bash
# Supabase
supabase start -o env              # Start services
supabase stop                      # Stop services
supabase status                    # Check status

# Project Management
airnub use ./project-name          # Switch to project
airnub db apply                    # Apply migrations
airnub db status                   # Check database status
airnub project current             # Show current project

# Template Management
scripts/sync-from-catalog.sh       # Sync latest template
```

### Essential Ports

| Service | Port | URL |
|---------|------|-----|
| Supabase API | 54321 | http://localhost:54321 |
| Supabase Studio | 54323 | http://localhost:54323 |
| noVNC Desktop | 6080 | http://localhost:6080 |
| Your App | 3000 | http://localhost:3000 |

**See:** [Ports & Services Reference](../reference/ports-and-services.md)

---

## Getting Help

- **Documentation:** [Documentation Index](../index.md)
- **Troubleshooting:** [Common Issues](../reference/troubleshooting.md)
- **Concepts:** [Core Concepts](./concepts.md)
- **Report Issues:** GitHub Issues on the workspace repository

---

**Congratulations! You're ready to start developing.** 🎉

**Last updated:** 2025-10-30
