# Troubleshooting Guide

This guide covers common issues you may encounter when working with the Airnub Meta Workspace and their solutions.

---

## Quick Diagnostics

Run these commands to check the health of your workspace:

```bash
# Check running containers
docker ps

# Check Supabase status
supabase status

# Check ports in use
ss -ltnp | egrep '6080|590|5432[1-4]|6379|3001|9222' || true

# Verify services are running
pgrep -a Xvfb; pgrep -a x11vnc; pgrep -a websockify; pgrep -a fluxbox || true

# Test noVNC access
curl -sSf http://localhost:6080/ | head -n2

# Check browser availability
command -v google-chrome || command -v chromium || echo "No Chrome/Chromium found"
```

---

## Common Issues

### 🔴 Supabase Issues

#### Problem: Port Collisions - Supabase won't start

**Symptoms:**
- `supabase start` fails with port binding errors
- Error messages like "port 54321 already in use"

**Causes:**
- Another Supabase instance is running locally
- Previous containers weren't cleaned up properly

**Solution:**
```bash
# Check for running Supabase containers
docker ps | grep supabase

# Stop all Supabase containers
docker ps -q --filter "name=supabase" | xargs -r docker stop

# Or stop from the workspace
supabase stop

# Clean up orphaned containers
docker container prune -f

# Restart Supabase
supabase start -o env
```

---

#### Problem: Stale Credentials - App can't connect to Supabase

**Symptoms:**
- Application shows authentication errors
- API calls return 401 or connection refused
- Environment variables don't match running services

**Causes:**
- Supabase was restarted and generated new credentials
- `.env.local` files are outdated

**Solution:**
```bash
# Refresh shared Supabase credentials
./supabase/scripts/db-env-local.sh --ensure-start

# Or using the airnub CLI
airnub db env sync --ensure-start

# Sync credentials to your project
cd /workspaces/your-project
airnub project env sync --project-dir "$(pwd)"

# Verify the credentials were updated
cat .env.local | grep SUPABASE
```

---

#### Problem: Migrations Fail to Apply

**Symptoms:**
- `supabase db push` fails with SQL errors
- Migration conflicts between projects

**Causes:**
- Shared Supabase has conflicting schema from another project
- Migration dependencies not met

**Solution:**
```bash
# Check current database state
supabase db status

# Reset the database (WARNING: destroys all data)
airnub db reset --project-dir ./your-project

# Or use Supabase CLI directly
supabase db reset --workdir ./your-project --local -y

# Reapply migrations
airnub db apply --project-dir ./your-project
```

---

#### Problem: Supabase Services Not Starting

**Symptoms:**
- `supabase status` shows services as "not running"
- Docker containers exit immediately

**Causes:**
- Insufficient Docker resources (memory/CPU)
- Corrupted Docker volumes

**Solution:**
```bash
# Check Docker resource usage
docker system df

# Check container logs
docker compose logs supabase

# Stop and clean up
supabase stop
docker volume prune -f

# Increase Docker resources (Docker Desktop: Settings → Resources)
# Recommended: 4GB+ RAM, 2+ CPUs

# Restart Supabase
supabase start -o env
```

---

### 🔴 Container & Environment Issues

#### Problem: Dev Container Build Fails

**Symptoms:**
- Container fails to start
- Build errors during initialization

**Causes:**
- Network issues downloading images
- Corrupted Docker cache
- GHCR authentication problems

**Solution:**
```bash
# Check Docker authentication
docker login ghcr.io

# Clear Docker build cache
docker builder prune -af

# Remove Dev Container volumes
docker volume ls | grep devcontainer | awk '{print $2}' | xargs -r docker volume rm

# Rebuild Dev Container (VS Code)
# Command Palette → "Dev Containers: Rebuild Container"

# Or using CLI
devcontainer up --workspace-folder . --remove-existing-container
```

---

#### Problem: GHCR Authentication Failures

**Symptoms:**
- "unauthorized" or "403 forbidden" when pulling images
- Private images can't be accessed

**Causes:**
- Missing or expired GitHub PAT
- PAT doesn't have correct permissions
- SSO not enabled on PAT

**Solution:**
1. **Create/Update PAT:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Repository access: Select repos with container images
   - Permissions: **Packages: Read** (for pulls), **Packages: Write** (for pushes)
   - **Enable SSO** for your organization

2. **Login to GHCR:**
```bash
docker logout ghcr.io || true
echo "$YOUR_PAT" | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

3. **For Codespaces:**
   - Add repository secrets: `GHCR_USER` and `GHCR_PAT`
   - Recreate the Codespace

---

#### Problem: Environment Variables Not Loading

**Symptoms:**
- Application can't find configuration
- Variables show as empty or undefined

**Causes:**
- `.env.local` files not created
- Variables not exported/loaded by application

**Solution:**
```bash
# Check if .env.local exists
ls -la .env.local

# If missing, create from example
cp .env.example .env.local

# Sync Supabase credentials
airnub project env sync --project-dir "$(pwd)"

# Verify variables
cat .env.local

# For shell sessions, export manually
set -a; source .env.local; set +a

# Restart your application to pick up changes
```

---

### 🔴 GUI & Desktop Issues

#### Problem: noVNC Desktop Not Loading

**Symptoms:**
- Port 6080 shows blank page or connection refused
- VNC viewer can't connect

**Causes:**
- X server (Xvfb) not running
- VNC server not started
- Port forwarding issues in Codespaces

**Solution:**
```bash
# Check if VNC processes are running
pgrep -a Xvfb
pgrep -a x11vnc
pgrep -a websockify

# Check if port 6080 is listening
ss -ltnp | grep 6080

# Restart noVNC services (if using docker compose)
docker compose restart novnc

# For Codespaces, check port forwarding
# Ports panel → Ensure 6080 is forwarded and visibility is correct

# Test local access
curl http://localhost:6080/
```

---

#### Problem: GUI Desktop Shows Wrong Resolution

**Symptoms:**
- Desktop appears too large/small
- Screen doesn't fit browser window

**Causes:**
- Xvfb started with fixed resolution
- noVNC remote resize not working

**Solution:**
```bash
# Check current display resolution
DISPLAY=:1 xrandr

# Restart with different resolution
# (Edit .devcontainer/docker-compose.yml or startup scripts)

# For noVNC, use resize parameter
# Open: http://localhost:6080/vnc.html?resize=remote&autoconnect=1
```

---

#### Problem: Chrome/Chromium Not Available in Desktop

**Symptoms:**
- Browser binary not found
- Can't launch Chrome from desktop

**Causes:**
- Chrome not installed during post-create
- Installation failed

**Solution:**
```bash
# Check if Chrome is installed
command -v google-chrome || command -v chromium

# Verify Chrome policies
cat /etc/opt/chrome/policies/managed/classroom.json

# Manual installation (if needed)
sudo apt-get update
sudo apt-get install -y google-chrome-stable

# Or Chromium
sudo apt-get install -y chromium-browser
```

---

### 🔴 Multi-Repo & Project Switching Issues

#### Problem: Repos Not Cloning Automatically

**Symptoms:**
- Expected repos missing from `/workspaces` or workspace root
- `postCreate` script skipped cloning

**Causes:**
- Missing permissions in `devcontainer.json`
- Authentication failed
- Script errors

**Solution:**
```bash
# Check devcontainer.json permissions
cat .devcontainer/devcontainer.json | grep -A 10 "repositories"

# Manually run clone script
ALLOW_WILDCARD=0 WORKSPACE_ROOT="$ROOT" \
  bash .devcontainer/scripts/clone-from-devcontainer-repos.sh

# Check script output for errors
# Verify authentication
gh auth status
```

---

#### Problem: App Server Port Collisions When Switching Projects

**Symptoms:**
- "Port 3000 already in use"
- Previous project's dev server still running

**Causes:**
- Forgot to stop previous project's server
- Process running in background

**Solution:**
```bash
# Find process using port 3000 (or other port)
lsof -ti:3000

# Kill the process
kill $(lsof -ti:3000)

# Or force kill
kill -9 $(lsof -ti:3000)

# List all node processes
ps aux | grep node

# Stop all node processes (careful!)
pkill -f node
```

---

#### Problem: Project Can't Find Shared Supabase

**Symptoms:**
- Connection errors to localhost:54321
- Database not found

**Causes:**
- Supabase not started
- Wrong connection string
- Environment variables not synced

**Solution:**
```bash
# Check if Supabase is running
supabase status

# If not running, start it
supabase start -o env

# Sync credentials to project
airnub use ./your-project

# Verify project .env.local has correct values
cat your-project/.env.local | grep SUPABASE_URL
# Should show: http://127.0.0.1:54321
```

---

### 🔴 Catalog & Sync Issues

#### Problem: Catalog Sync Fails

**Symptoms:**
- `sync-from-catalog.sh` errors out
- `.devcontainer/` is empty or corrupted

**Causes:**
- Network timeout downloading tarball
- Invalid `CATALOG_REF` or `TEMPLATE` name
- Corrupted download

**Solution:**
```bash
# Verify CATALOG_REF and TEMPLATE values
echo $CATALOG_REF
echo $TEMPLATE

# Try with explicit values
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Check network connectivity
curl -I https://github.com/airnub-labs/devcontainers-catalog

# If download is interrupted, clear temp files
rm -rf /tmp/catalog-*

# Re-run sync
scripts/sync-from-catalog.sh
```

---

### 🔴 Performance Issues

#### Problem: Workspace is Slow

**Symptoms:**
- High CPU/memory usage
- Operations take long time
- System becomes unresponsive

**Causes:**
- Too many containers running
- Insufficient Docker resources
- Large Docker cache

**Solution:**
```bash
# Check resource usage
docker stats

# Stop unnecessary services
docker compose stop novnc  # If not using GUI
supabase stop             # If not actively developing

# Clean up Docker
docker system prune -af
docker volume prune -f

# Check disk space
df -h

# Increase Docker resources (Docker Desktop)
# Settings → Resources → Increase Memory to 4GB+, CPUs to 2+

# Restart Docker daemon
```

---

## Getting More Help

### Diagnostic Information to Share

When reporting issues, include:

```bash
# System info
uname -a
docker version
docker compose version

# Container status
docker ps -a

# Supabase status
supabase status

# Logs
docker compose logs --tail=50
```

### Where to Get Help

- **Documentation:** [docs/index.md](../index.md)
- **Issues:** Open an issue with diagnostic info
- **Logs:** Check `.devcontainer/scripts/*.log` if available

---

## Preventive Maintenance

Run these periodically to keep workspace healthy:

```bash
# Weekly cleanup
docker system prune -f
docker volume prune -f

# Monthly full cleanup
docker system prune -af --volumes

# Check for updates
git pull origin main
TEMPLATE=your-stack scripts/sync-from-catalog.sh

# Verify services
supabase status
airnub db status
```

---

**Last updated:** 2025-10-30
