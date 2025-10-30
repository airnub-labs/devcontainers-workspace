# Ports and Services Reference

This document provides a comprehensive reference of all ports and services used in the Airnub Meta Workspace. All port assignments are standardized across the workspace to prevent conflicts and enable the shared services model.

---

## Quick Reference Table

| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **Supabase API** | 54321 | HTTP | Private | REST/Realtime API endpoint |
| **Supabase Postgres** | 54322 | TCP | Private | Direct database access |
| **Supabase Studio** | 54323 | HTTP | Private | Web UI for database management |
| **Supabase Inbucket** | 54324 | HTTP | Private | Email testing inbox |
| **Supabase Storage** | 54326 | HTTP | Private | Object storage API |
| **Supabase Analytics** | 54327 | HTTP | Private | Logflare analytics endpoint |
| **Redis** | 6379 | TCP | Private | Shared cache/data store |
| **noVNC Desktop** | 6080 | HTTP | Private | Browser-based VNC desktop |
| **noVNC Audio Bridge** | 6081 | HTTP | Private | Audio streaming (Opus/OGG) |
| **Webtop Desktop** | 3001 | HTTPS | Private | LinuxServer Webtop GUI |
| **Chrome Desktop** | 3002 | HTTPS | Private | LinuxServer Chrome GUI |
| **noVNC DevTools** | 9222 | HTTP | Private | Chrome DevTools Protocol |
| **Webtop DevTools** | 9223 | HTTP | Private | Chrome DevTools Protocol |
| **Chrome DevTools** | 9224 | HTTP | Private | Chrome DevTools Protocol |

---

## Supabase Stack Ports

The Supabase CLI manages a stack of services when you run `supabase start`. All services bind to localhost and are accessible within the Dev Container.

### Core Supabase Services

#### 🌐 API Gateway (Port 54321)
**Service:** Kong API Gateway
**Purpose:** Main entry point for all Supabase client requests
**Protocols:** REST API, Realtime (WebSocket)
**Configuration:** `supabase/config.toml`

**Usage in your app:**
```typescript
const supabase = createClient(
  'http://127.0.0.1:54321',  // API URL
  'your-anon-key'
)
```

**Environment variable:** `SUPABASE_URL` or `SUPABASE_API_URL`

---

#### 🗄️ PostgreSQL Database (Port 54322)
**Service:** PostgreSQL 15+
**Purpose:** Direct database access for migrations and admin tools
**Connection:** Used by Supabase CLI during `db push`, `db reset`

**Connection string format:**
```
postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

**Environment variables:**
- `SUPABASE_DB_URL`
- `DATABASE_URL` (often used by ORMs)

**Common use cases:**
- Running migrations with Supabase CLI
- Direct SQL access via `psql`
- Database inspection tools

---

#### 🎨 Studio Web UI (Port 54323)
**Service:** Supabase Studio
**Purpose:** Web-based database management interface
**Access:** Open http://localhost:54323 in your browser

**Features:**
- Table editor
- SQL editor
- Auth user management
- Storage file browser
- Database schema visualization
- Real-time logs

**Codespaces URL pattern:**
```
https://<workspace>-54323.<region>.codespaces-preview.app
```

---

#### 📧 Email Testing - Inbucket (Port 54324)
**Service:** Inbucket
**Purpose:** Catch all emails sent by your app during development
**Access:** http://localhost:54324

**Use cases:**
- Test password reset emails
- Verify email templates
- Debug authentication flows

**Configuration:**
- All emails are captured locally
- No external email delivery
- Emails persist until container restart

---

#### 📦 Object Storage (Port 54326)
**Service:** Storage API (backed by Minio)
**Purpose:** S3-compatible object storage
**Access:** Via Supabase client or direct API calls

**Usage:**
```typescript
const { data } = await supabase.storage
  .from('avatars')
  .upload('user-1.png', file)
```

**Persistence:**
- Files stored in `supabase/docker/volumes/minio/`
- Survives container restarts
- Gitignored (not committed)

---

#### 📊 Analytics - Logflare (Port 54327)
**Service:** Logflare analytics
**Purpose:** Logging and analytics aggregation
**Access:** Typically via Studio UI or API

**Environment variable:** `SUPABASE_ANALYTICS_URL`

---

## GUI Desktop Providers

The workspace supports multiple GUI providers for browser-based desktop access. Only one is typically active at a time (configured via `GUI_PROVIDERS` in `.devcontainer/.env`).

### noVNC Desktop (Port 6080)

**Service:** noVNC + Xvfb + Fluxbox
**Purpose:** Lightweight browser-based VNC desktop
**Access:** http://localhost:6080

**Features:**
- Auto-connect landing page
- Remote resize support
- Clipboard integration
- Audio bridge on port 6081

**Configuration:**
```bash
# In .devcontainer/.env
GUI_PROVIDERS=novnc
GUI_NOVNC_HTTP_PORT=6080
GUI_NOVNC_DEVTOOLS_PORT=9222
```

**Codespaces access:**
```
https://<workspace>-6080.<region>.codespaces-preview.app
```

**Related ports:**
- **6081:** Audio bridge (Opus/OGG streaming)
- **9222:** Chrome DevTools Protocol (when browser debugging enabled)

**Display configuration:**
- Default resolution: 1920x1080
- Configurable via Xvfb startup parameters
- Use `DISPLAY=:1 xrandr` to check current resolution

---

### Webtop Desktop (Port 3001)

**Service:** LinuxServer Webtop
**Purpose:** Full-featured HTTPS desktop with audio/video
**Access:** https://localhost:3001 (HTTPS required for audio)

**Features:**
- Full Ubuntu desktop (XFCE or KDE)
- WebRTC audio/video streaming
- Hardware acceleration support
- Multiple browser options

**Configuration:**
```bash
# In .devcontainer/.env
GUI_PROVIDERS=webtop
GUI_WEBTOP_HTTPS_PORT=3001
GUI_WEBTOP_DEVTOOLS_PORT=9223
WEBTOP_USER=abc
WEBTOP_PASSWORD=your-password
WEBTOP_AUDIO=1  # Enable audio (default)
```

**Authentication:**
- Basic auth credentials from `WEBTOP_USER` / `WEBTOP_PASSWORD`
- Keep port forwarding private in Codespaces

**Related ports:**
- **9223:** Chrome DevTools Protocol

---

### Chrome Desktop (Port 3002)

**Service:** LinuxServer Chrome
**Purpose:** Standalone Chrome browser in containerized desktop
**Access:** https://localhost:3002

**Configuration:**
```bash
# In .devcontainer/.env
GUI_PROVIDERS=chrome
GUI_CHROME_HTTPS_PORT=3002
GUI_CHROME_DEVTOOLS_PORT=9224
CHROME_USER=abc
CHROME_PASSWORD=your-password
```

**Use cases:**
- Isolated browser for testing
- Chromium-based automation
- Visual regression testing

**Related ports:**
- **9224:** Chrome DevTools Protocol

---

## Chrome DevTools Protocol (CDP)

All GUI providers can expose Chrome DevTools Protocol for remote debugging and automation.

### Port Assignments

| Provider | CDP Port | Configuration Variable |
|----------|----------|------------------------|
| noVNC | 9222 | `GUI_NOVNC_DEVTOOLS_PORT` |
| Webtop | 9223 | `GUI_WEBTOP_DEVTOOLS_PORT` |
| Chrome | 9224 | `GUI_CHROME_DEVTOOLS_PORT` |

### Enabling CDP

```bash
# In .devcontainer/.env
GUI_CHROME_DEBUG=1  # Enable DevTools for all providers
```

### Usage

**List debugging targets:**
```bash
curl http://localhost:9222/json
```

**Connect with Chrome DevTools:**
1. Open chrome://inspect in your local Chrome
2. Configure network target: `localhost:9222`
3. Inspect remote browser

**Playwright connection:**
```typescript
import { chromium } from 'playwright';

const browser = await chromium.connectOverCDP('http://localhost:9222');
```

---

## Redis (Port 6379)

**Service:** Redis 7 Alpine
**Purpose:** Shared cache and data store
**Access:** localhost:6379 (no authentication by default)

**Configuration:** `.devcontainer/docker-compose.yml`

**Usage:**
```bash
# Connect with redis-cli
redis-cli -h localhost -p 6379

# From your app
const redis = new Redis({
  host: 'localhost',
  port: 6379
});
```

**Environment variable:** `REDIS_URL=redis://localhost:6379`

**Persistence:**
- Data stored in Docker volume
- Survives container restarts
- Not backed by bind mount (ephemeral across rebuilds)

---

## Port Forwarding in Codespaces

All ports are marked as **Private** by default in `devcontainer.json`. This means:

- Ports are only accessible to the authenticated user
- URLs are unique per session
- No public internet access

### URL Format

```
https://<workspace>-<port>.<region>.codespaces-preview.app
```

**Example:**
- Supabase Studio: `https://fuzzy-space-disco-abc123-54323.app.github.dev`
- noVNC: `https://fuzzy-space-disco-abc123-6080.app.github.dev`

### Changing Port Visibility

In the Codespaces Ports panel:
- Right-click a port → "Port Visibility"
- Options: Private, Public, Organization

**⚠️ Security Warning:** Never make GUI desktops or Supabase public without proper authentication.

---

## Port Conflicts & Troubleshooting

### Common Conflicts

**Symptom:** "Port already in use" errors

**Causes:**
1. Previous container not cleaned up
2. Multiple Supabase instances running
3. Local services using same ports

**Solutions:**

```bash
# Check what's using a port
lsof -i :54321

# Kill process on port
kill $(lsof -ti:54321)

# Stop all Supabase containers
docker ps | grep supabase | awk '{print $1}' | xargs docker stop

# Clean up orphaned containers
docker container prune -f
```

### Verifying Services

```bash
# Check all workspace ports
ss -ltnp | egrep '6080|590|5432[1-4]|6379|3001|9222'

# Check Supabase specifically
supabase status

# Test port accessibility
curl http://localhost:54323  # Should return Studio HTML
curl http://localhost:6080   # Should return noVNC HTML
```

---

## Environment Variable Reference

Common environment variables for service configuration:

### Supabase

```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<generated-by-cli>
SUPABASE_SERVICE_ROLE_KEY=<generated-by-cli>
SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

### Redis

```bash
REDIS_URL=redis://localhost:6379
```

### GUI Providers

```bash
# noVNC
GUI_NOVNC_HTTP_PORT=6080
GUI_NOVNC_DEVTOOLS_PORT=9222

# Webtop
GUI_WEBTOP_HTTPS_PORT=3001
GUI_WEBTOP_DEVTOOLS_PORT=9223
WEBTOP_USER=abc
WEBTOP_PASSWORD=your-password

# Chrome
GUI_CHROME_HTTPS_PORT=3002
GUI_CHROME_DEVTOOLS_PORT=9224
```

---

## Stack-Specific Port Assignments

Different stack templates may use different GUI providers. Always check your stack's README for the specific ports.

### stack-nextjs-supabase-webtop

- Supabase: 54321-54327
- Webtop: 3001 (HTTPS)
- Webtop CDP: 9223
- Redis: 6379

### stack-nextjs-supabase-novnc

- Supabase: 54321-54327
- noVNC: 6080 (HTTP)
- noVNC Audio: 6081
- noVNC CDP: 9222
- Redis: 6379

---

## Service Health Checks

### Quick Health Check Script

```bash
#!/bin/bash
# Check all services

echo "=== Supabase ==="
supabase status 2>&1 | head -n 10

echo -e "\n=== Redis ==="
redis-cli -h localhost -p 6379 ping 2>&1 || echo "Redis not responding"

echo -e "\n=== noVNC ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:6080/ 2>&1

echo -e "\n=== Port Listeners ==="
ss -ltnp | egrep '6080|590|5432[1-4]|6379|3001'
```

---

## Related Documentation

- **[Troubleshooting Guide](./troubleshooting.md)** - Solutions for port conflicts and service issues
- **[Supabase Operations](../guides/supabase-operations.md)** - How to use the shared Supabase stack
- **[GUI Desktop Providers](../guides/gui-desktops.md)** - Detailed GUI provider configuration
- **[Container Architecture](../architecture/container-layers.md)** - Understanding the container layers

---

**Last updated:** 2025-10-30
