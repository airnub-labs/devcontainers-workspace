# Coding Agent Prompt — Separate **Catalog** vs **Workspaces** (novnc + webtop variants)

> **Goal**: Keep a single repo for now, but clearly separate the **catalog** (Features/Templates/Images/Docs) from **workspace variants**. Create two workspace variants under `workspaces/`: **webtop** and **novnc**. Each variant has its own `.devcontainer/`, `.code-workspace`, and a `workspace.blueprint.json` to dynamically clone project repos on first open (so you don’t hard‑wire folders like `million-dollar-maps`).
>
> This prompt operates on the current repo (root tree you provided). It makes no assumption that `million-dollar-maps` is committed; cloning is blueprint-driven.

---

## 0) Branch & safety

1. Create a new branch:

   ```bash
   git checkout -b chore/separate-catalog-and-workspaces
   ```
2. Ensure a clean working tree before file moves (stash if needed).

---

## 1) Create high-level layout

**Catalog stays at root**:

* `features/`, `templates/`, `images/`, `docs/`, `scripts/` remain unchanged (publisher assets).

**Add Workspaces area**:

```bash
mkdir -p workspaces/webtop/.devcontainer \
         workspaces/novnc/.devcontainer \
         workspaces/_shared \
         apps
```

**Ignore cloned app repos**:

```bash
if ! grep -q "^apps/" .gitignore 2>/dev/null; then echo "apps/" >> .gitignore; fi
```

---

## 2) Move workspace-specific content under `workspaces/_shared`

> We treat `supabase/` and `airnub/` as **workspace resources**, not catalog. If a directory is missing locally, skip the move.

```bash
# supabase workspace assets
if [ -d supabase ]; then git mv supabase workspaces/_shared/supabase; fi

# optional org/workspace files
if [ -d airnub ]; then git mv airnub workspaces/_shared/airnub; fi
```

> Do **not** move `million-dollar-maps/`. It will be cloned on demand into `/apps` via the blueprint.

---

## 3) Workspace variant: **webtop**

### 3.1 Devcontainer (compose + features)

Create `workspaces/webtop/.devcontainer/devcontainer.json`:

```json
{
  "name": "airnub — webtop",
  "dockerComposeFile": ["./compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "webtop", "redis"],

  "workspaceMount": "source=${localWorkspaceFolder}/../..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",

  "features": {
    "../../../features/supabase-cli": { "manageLocalStack": true },
    "../../../features/chrome-cdp": { "port": 9222 },
    "../../../features/agent-tooling-clis": {},
    "../../../features/docker-in-docker-plus": {}
  },

  "forwardPorts": [9222, 3001, 6379, 54323],
  "portsAttributes": {
    "9222": { "label": "Chrome DevTools (CDP)" },
    "3001": { "label": "Desktop (webtop)" },
    "6379": { "label": "Redis" },
    "54323": { "label": "Supabase Studio" }
  },

  "postCreateCommand": "bash workspaces/webtop/postCreate.sh",
  "postStartCommand": "bash workspaces/webtop/postStart.sh",

  "customizations": {
    "vscode": {
      "settings": {
        "files.exclude": { "**/.git": true, "**/node_modules": true },
        "terminal.integrated.defaultProfile.linux": "bash"
      },
      "extensions": [
        "ms-vscode.vscode-typescript-next",
        "esbenp.prettier-vscode",
        "github.vscode-github-actions"
      ]
    }
  }
}
```

Create `workspaces/webtop/.devcontainer/compose.yaml`:

```yaml
services:
  dev:
    image: ghcr.io/airnub-labs/dev-web:latest
    user: "vscode"
    volumes:
      - ../..:/workspaces:cached
    shm_size: "2gb"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  webtop:
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - CUSTOM_USER=vscode
    volumes:
      - ../..:/workspace
      - ../../docs:/workspace/docs:ro
    ports:
      - "3001:3000"
    shm_size: "2gb"
```

### 3.2 Post hooks & blueprint

Create `workspaces/webtop/postCreate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Ensure PNPM store is writable (if node present)
mkdir -p /home/vscode/.pnpm-store && chown -R vscode:vscode /home/vscode/.pnpm-store || true

# Clone repos from blueprint (JSON parsed via node)
BP=workspaces/webtop/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/webtop/workspace.blueprint.json','utf8'));
  const repos = (bp.repos||[]);
  for (const r of repos) {
    const { url, path, ref } = r;
    if (!url || !path) continue;
    if (!fs.existsSync(path)) {
      console.log(`[clone] ${url} -> ${path}`);
      execSync(`git clone ${url} ${path}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${path} checkout ${ref}`, { stdio: 'inherit' });
    } else {
      console.log(`[skip] exists: ${path}`);
    }
  }
NODE
fi

# Print tool versions (non-fatal if missing)
node -v || true
pnpm -v || true
supabase --version || true
```

Create `workspaces/webtop/postStart.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Optional: start local supabase stack (comment out to keep manual control)
# supabase start || true
```

Create `workspaces/webtop/workspace.blueprint.json` (editable manifest):

```json
{
  "repos": [
    { "url": "https://github.com/airnub-labs/million-dollar-maps", "path": "apps/million-dollar-maps", "ref": "main" }
  ]
}
```

Create `workspaces/webtop/airnub-webtop.code-workspace`:

```json
{
  "folders": [
    { "path": "../../workspaces/_shared/supabase" },
    { "path": "../../apps" },
    { "path": "../../docs" }
  ],
  "settings": {
    "files.exclude": { "**/.git": true, "**/node_modules": true }
  }
}
```

---

## 4) Workspace variant: **novnc**

### 4.1 Devcontainer

Create `workspaces/novnc/.devcontainer/devcontainer.json`:

```json
{
  "name": "airnub — novnc",
  "dockerComposeFile": ["./compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "novnc", "redis"],

  "workspaceMount": "source=${localWorkspaceFolder}/../..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",

  "features": {
    "../../../features/supabase-cli": { "manageLocalStack": true },
    "../../../features/chrome-cdp": { "port": 9222 },
    "../../../features/agent-tooling-clis": {},
    "../../../features/docker-in-docker-plus": {}
  },

  "forwardPorts": [9222, 6080, 6379, 54323],
  "portsAttributes": {
    "9222": { "label": "Chrome DevTools (CDP)" },
    "6080": { "label": "Desktop (noVNC)" },
    "6379": { "label": "Redis" },
    "54323": { "label": "Supabase Studio" }
  },

  "postCreateCommand": "bash workspaces/novnc/postCreate.sh",
  "postStartCommand": "bash workspaces/novnc/postStart.sh"
}
```

Create `workspaces/novnc/.devcontainer/compose.yaml`:

```yaml
services:
  dev:
    image: ghcr.io/airnub-labs/dev-web:latest
    user: "vscode"
    volumes:
      - ../..:/workspaces:cached
    shm_size: "2gb"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  novnc:
    image: dorowu/ubuntu-desktop-lxde-vnc:latest
    environment:
      - TZ=Etc/UTC
    ports:
      - "6080:80"    # Web VNC
    shm_size: "1gb"
```

### 4.2 Post hooks & workspace file

Create `workspaces/novnc/postCreate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BP=workspaces/novnc/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/novnc/workspace.blueprint.json','utf8'));
  const repos = (bp.repos||[]);
  for (const r of repos) {
    const { url, path, ref } = r;
    if (!url || !path) continue;
    if (!fs.existsSync(path)) {
      console.log(`[clone] ${url} -> ${path}`);
      execSync(`git clone ${url} ${path}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${path} checkout ${ref}`, { stdio: 'inherit' });
    }
  }
NODE
fi
```

Create `workspaces/novnc/postStart.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Optional: supabase start
# supabase start || true
```

Create `workspaces/novnc/workspace.blueprint.json`:

```json
{ "repos": [] }
```

Create `workspaces/novnc/airnub-novnc.code-workspace`:

```json
{
  "folders": [
    { "path": "../../workspaces/_shared/supabase" },
    { "path": "../../apps" },
    { "path": "../../docs" }
  ]
}
```

---

## 5) Move old workspace file into the **webtop** variant

If `airnub-labs.code-workspace` exists at repo root, move it and let the new one replace it or keep both:

```bash
if [ -f airnub-labs.code-workspace ]; then git mv airnub-labs.code-workspace workspaces/webtop/airnub-webtop.code-workspace; fi
```

---

## 6) Docs touch-up (optional but recommended)

Append to `docs/workspace-architecture.md` a short section:

```md
## Workspaces layout
- Catalog (publisher): features/, templates/, images/, docs/
- Workspaces: workspaces/<variant> with its own .devcontainer and .code-workspace.
- Apps cloned dynamically into /apps via workspaces/<variant>/workspace.blueprint.json
```

---

## 7) Commit & PR

```bash
git add -A
git commit -m "chore(workspaces): split catalog vs workspace; add webtop and novnc variants"
# Open a PR via your normal flow
```

---

## 8) How to use

* **Webtop variant**: open `workspaces/webtop/airnub-webtop.code-workspace` → container builds (dev + redis + webtop), ports 3001/9222/6379 forwarded.
* **noVNC variant**: open `workspaces/novnc/airnub-novnc.code-workspace` → container builds (dev + redis + novnc), ports 6080/9222/6379 forwarded.
* To add/remove project repos, **edit the variant’s `workspace.blueprint.json`**; they’ll clone into `/apps` on next build without editing the workspace file.

---

## 9) Acceptance checks

* Both variants build in Dev Containers and show only: `/apps`, `/docs`, `/workspaces/_shared/supabase` in VS Code.
* `supabase --version` works; `supabase start` runs manually or via `postStart.sh`.
* Webtop shows desktop at `localhost:3001`; novnc shows desktop at `localhost:6080`.
* CDP reachable at `localhost:9222/json/version`.
* Editing `workspace.blueprint.json` causes repos to appear under `/apps` on rebuild.

---

## 10) Future (optional)

* Add a **“sync from template”** Action that periodically updates each variant’s `.devcontainer/` from `templates/classroom-studio-webtop` with a PR.
* Add an **MCP Workspace Factory** endpoint that creates additional variants on demand from your catalog.
