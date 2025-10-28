# Coding Agent Migration Prompt — Move legacy `.devcontainer` → `workspaces/*` (webtop + novnc) **and** add a root Codespaces bridge (v0.3)

> **Why you’re running this:** The repo now has `workspaces/webtop/.devcontainer` and `workspaces/novnc/.devcontainer`, but the **original root `.devcontainer/` has not been migrated**. This prompt moves the legacy config/scripts into the new **variant** layout, replaces bespoke bits with proper **Features/Templates**, and adds a **root `.devcontainer` bridge** so Codespaces works out‑of‑the‑box.
>
> **Safe‑by‑default:** Everything below is idempotent and guarded with existence checks. Legacy assets are archived under `workspaces/_legacy/` so nothing is lost.

---

## 0) Preflight & Branch

```bash
set -euo pipefail
BRANCH="chore/migrate-root-devcontainer-to-workspaces"
git checkout -b "$BRANCH" || git checkout "$BRANCH" || true

# Ensure dirs
mkdir -p workspaces/webtop/.devcontainer \
         workspaces/novnc/.devcontainer \
         workspaces/_shared \
         workspaces/_legacy \
         apps \
         .devcontainer/webtop .devcontainer/novnc

# Ignore cloned app repos
if ! grep -q "^apps/" .gitignore 2>/dev/null; then echo "apps/" >> .gitignore; fi
```

---

## 1) Classify legacy root `.devcontainer` contents

> **Input (expected from older setup):**
>
> Files like:
> - `.devcontainer/devcontainer.json`
> - `.devcontainer/docker-compose.yml` (or `compose.yml`)
> - `.devcontainer/Dockerfile`
> - scripts: `chrome-devtools.sh`, `webtop-devtools.sh`, `start-desktop.sh`, `apply-chrome-policy.sh`, `fluxbox-setup.sh`, `novnc-audio-bridge.sh`, `post-create.sh`, `post-start.sh`, `supabase-up.sh`, `select-gui-profiles.sh`, `clone-from-devcontainer-repos.sh`, `install-deno-cli.sh`
>
> **Strategy:**
> - Prefer **Features** for tools (Chrome CDP, Supabase CLI, agent tooling).
> - Prefer **sidecar images** for GUI desktops (webtop/noVNC) via **Template**/compose instead of in‑container scripts.
> - Any **still‑useful custom scripts** are moved to the specific variant and invoked by `postCreate`/`postStart`.
> - Obsolete / duplicate installers get archived in `workspaces/_legacy/`.

---

## 2) Move legacy files to **webtop** variant (primary)

```bash
# Compose/Dockerfile → webtop variant
if [ -f .devcontainer/docker-compose.yml ]; then
  mv .devcontainer/docker-compose.yml workspaces/webtop/.devcontainer/compose.legacy.yml
fi
if [ -f .devcontainer/compose.yml ]; then
  mv .devcontainer/compose.yml workspaces/webtop/.devcontainer/compose.legacy.yml
fi
if [ -f .devcontainer/Dockerfile ]; then
  mv .devcontainer/Dockerfile workspaces/webtop/.devcontainer/Dockerfile.legacy
fi

# Generic hooks → webtop (we'll rewire them in devcontainer.json)
for f in post-create.sh post-start.sh chrome-devtools.sh webtop-devtools.sh apply-chrome-policy.sh \
         start-desktop.sh supabase-up.sh install-deno-cli.sh; do
  [ -f ".devcontainer/$f" ] && mv ".devcontainer/$f" "workspaces/webtop/$f" || true
done

# noVNC/Fluxbox/audio bits copy to **both** for reuse
for f in fluxbox-setup.sh novnc-audio-bridge.sh; do
  [ -f ".devcontainer/$f" ] && cp ".devcontainer/$f" "workspaces/novnc/$f" || true
  [ -f ".devcontainer/$f" ] && cp ".devcontainer/$f" "workspaces/webtop/$f" || true
done

# Legacy multi‑profile selector & repo‑clone scripts → archive (superseded by per‑variant + blueprint)
for f in select-gui-profiles.sh clone-from-devcontainer-repos.sh; do
  [ -f ".devcontainer/$f" ] && mv ".devcontainer/$f" workspaces/_legacy/ || true
done
```

> **Note:** The **webtop** variant is the default UX. We’ll generate clean `compose.yaml` files per variant (webtop/noVNC) and keep any previous compose as `compose.legacy.yml` for reference.

---

## 3) Create clean **compose.yaml** for each variant

### 3.1 `workspaces/webtop/.devcontainer/compose.yaml`
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

### 3.2 `workspaces/novnc/.devcontainer/compose.yaml`
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
      - "6080:80"
    shm_size: "1gb"
```

> If your legacy compose starts Chrome or audio bridges inside the **dev** container, prefer to move those to GUI sidecars or features. Keep bespoke behavior in variant scripts if still needed.

---

## 4) Create **devcontainer.json** per variant

### 4.1 `workspaces/webtop/.devcontainer/devcontainer.json`
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
  "postStartCommand": "bash workspaces/webtop/postStart.sh"
}
```

### 4.2 `workspaces/novnc/.devcontainer/devcontainer.json`
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

---

## 5) Root **Codespaces bridge** (default webtop + picker options)

```bash
# Default bridge → webtop
cat > .devcontainer/devcontainer.json << 'JSON'
{
  "name": "airnub — webtop (default)",
  "dockerComposeFile": ["../workspaces/webtop/.devcontainer/compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "webtop", "redis"],
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",
  "features": {
    "../features/supabase-cli": { "manageLocalStack": true },
    "../features/chrome-cdp": { "port": 9222 },
    "../features/agent-tooling-clis": {},
    "../features/docker-in-docker-plus": {}
  },
  "forwardPorts": [9222, 3001, 6379, 54323],
  "portsAttributes": {"9222": {"label": "Chrome DevTools (CDP)"}, "3001": {"label": "Desktop (webtop)"}, "6379": {"label": "Redis"}, "54323": {"label": "Supabase Studio"}},
  "postCreateCommand": "bash workspaces/webtop/postCreate.sh",
  "postStartCommand": "bash workspaces/webtop/postStart.sh"
}
JSON

# Picker profiles
cat > .devcontainer/webtop/devcontainer.json << 'JSON'
{
  "name": "airnub — webtop",
  "dockerComposeFile": ["../../workspaces/webtop/.devcontainer/compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "webtop", "redis"],
  "workspaceMount": "source=${localWorkspaceFolder}/..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",
  "features": {
    "../../features/supabase-cli": { "manageLocalStack": true },
    "../../features/chrome-cdp": { "port": 9222 },
    "../../features/agent-tooling-clis": {},
    "../../features/docker-in-docker-plus": {}
  },
  "forwardPorts": [9222, 3001, 6379, 54323],
  "portsAttributes": {"9222": {"label": "Chrome DevTools (CDP)"}, "3001": {"label": "Desktop (webtop)"}, "6379": {"label": "Redis"}, "54323": {"label": "Supabase Studio"}},
  "postCreateCommand": "bash workspaces/webtop/postCreate.sh",
  "postStartCommand": "bash workspaces/webtop/postStart.sh"
}
JSON

cat > .devcontainer/novnc/devcontainer.json << 'JSON'
{
  "name": "airnub — novnc",
  "dockerComposeFile": ["../../workspaces/novnc/.devcontainer/compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "novnc", "redis"],
  "workspaceMount": "source=${localWorkspaceFolder}/..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces",
  "features": {
    "../../features/supabase-cli": { "manageLocalStack": true },
    "../../features/chrome-cdp": { "port": 9222 },
    "../../features/agent-tooling-clis": {},
    "../../features/docker-in-docker-plus": {}
  },
  "forwardPorts": [9222, 6080, 6379, 54323],
  "portsAttributes": {"9222": {"label": "Chrome DevTools (CDP)"}, "6080": {"label": "Desktop (noVNC)"}, "6379": {"label": "Redis"}, "54323": {"label": "Supabase Studio"}},
  "postCreateCommand": "bash workspaces/novnc/postCreate.sh",
  "postStartCommand": "bash workspaces/novnc/postStart.sh"
}
JSON
```

---

## 6) Wire post hooks and blueprint (create if missing)

```bash
# Webtop hooks (create only if missing)
[ -f workspaces/webtop/postCreate.sh ] || cat > workspaces/webtop/postCreate.sh << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p /home/vscode/.pnpm-store && chown -R vscode:vscode /home/vscode/.pnpm-store || true
BP=workspaces/webtop/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/webtop/workspace.blueprint.json','utf8'));
  for (const r of (bp.repos||[])) {
    const { url, path, ref } = r; if (!url||!path) continue;
    if (!fs.existsSync(path)) {
      console.log(`[clone] ${url} -> ${path}`);
      execSync(`git clone ${url} ${path}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${path} checkout ${ref}`, { stdio: 'inherit' });
    }
  }
NODE
fi
node -v || true; pnpm -v || true; supabase --version || true
BASH
chmod +x workspaces/webtop/postCreate.sh

[ -f workspaces/webtop/postStart.sh ] || cat > workspaces/webtop/postStart.sh << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
# Optional: supabase start || true
BASH
chmod +x workspaces/webtop/postStart.sh

# Blueprint defaults
[ -f workspaces/webtop/workspace.blueprint.json ] || cat > workspaces/webtop/workspace.blueprint.json << 'JSON'
{
  "repos": [
    { "url": "https://github.com/airnub-labs/million-dollar-maps", "path": "apps/million-dollar-maps", "ref": "main" }
  ]
}
JSON

# Mirror for novnc
[ -f workspaces/novnc/postCreate.sh ] || cp workspaces/webtop/postCreate.sh workspaces/novnc/postCreate.sh
[ -f workspaces/novnc/postStart.sh ]  || cp workspaces/webtop/postStart.sh  workspaces/novnc/postStart.sh
[ -f workspaces/novnc/workspace.blueprint.json ] || echo '{"repos":[]}' > workspaces/novnc/workspace.blueprint.json
```

---

## 7) Script permissions & shebang fixes

```bash
# Mark any moved scripts executable
for d in workspaces/webtop workspaces/novnc; do
  find "$d" -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} + || true
  find "$d/.devcontainer" -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} + || true
done
```

---

## 8) Remove/Archive empty legacy `.devcontainer`

```bash
# If anything remains in root .devcontainer that we didn't move, archive it.
if [ -d .devcontainer ]; then
  for f in $(ls -A .devcontainer || true); do
    case "$f" in
      devcontainer.json|webtop|novnc) ;; # keep bridge
      *) mv ".devcontainer/$f" workspaces/_legacy/ || true ;;
    esac
  done
fi
```

---

## 9) Acceptance tests (local or in Codespaces)

```bash
# Build webtop variant via root bridge
# (In Codespaces, simply create a codespace. Locally with Dev Containers extension, build from repo root.)

# Health checks (once running):
curl -fsSL http://localhost:9222/json/version | jq .Browser || echo "CDP not responding yet"
# Webtop desktop:
curl -I http://localhost:3001 || true
# noVNC desktop (only in novnc profile):
curl -I http://localhost:6080 || true
# Redis:
redis-cli -h 127.0.0.1 -p 6379 PING || true
# Optional: Supabase Studio (after supabase start)
curl -I http://localhost:54323 || true
```

**Pass criteria:**
- Codespaces default build uses **webtop** and forwards 3001/9222/6379.
- `http://localhost:9222/json/version` returns Chrome CDP JSON.
- `http://localhost:3001` (webtop) or `http://localhost:6080` (noVNC) serves a page.
- Redis `PING` → `PONG`.

---

## 10) Commit & PR

```bash
git add -A
git commit -m "chore(devcontainer): migrate legacy root .devcontainer into workspaces variants; add Codespaces bridge"
# open PR via your normal flow
```

---

## 11) Notes & choices

- **Dockerfile.legacy**: If your legacy `Dockerfile` installs tools that now exist as **Features** (`supabase-cli`, `chrome-cdp`, `agent-tooling-clis`), prefer to **delete** those steps and rely on features. If you still need a custom base, move it to `images/dev-web/` and update both variants to `build:` instead of `image:`.
- **Audio for noVNC**: If `novnc-audio-bridge.sh` was used, create an `audio` sidecar or extend the `novnc` service with that script in its entrypoint.
- **Chrome policies**: Mount policies into the GUI sidecar (e.g., map `workspaces/webtop/policies:/etc/opt/chrome/policies/managed:ro`).
- **Repo cloning**: Legacy `clone-from-devcontainer-repos.sh` is superseded by `workspace.blueprint.json` + `postCreate.sh`.

---

## 12) Optional: GH Actions smoke tests

Add a job that materializes each variant, executes `devcontainer build`, and probes ports. Use Actions service containers if you want to curl the desktops.

---

**End — v0.3**

