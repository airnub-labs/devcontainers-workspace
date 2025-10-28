# Classroom Studio SaaS — Spec & Architecture (v0.1)

> Turn-key, spec‑aligned Dev Container environments for entire classes. Instructors set the stack once; every student gets an identical, working workspace with preloaded repos, tools, policies, and lesson content — on laptop, tablet, or phone.

---

## 1) Product Goals

**Primary outcome**: Eliminate setup friction. Day‑one students code immediately; instructors teach instead of debugging tooling.

**Key goals**
- 1‑click provisioning of consistent, version‑pinned Dev Container environments per student/cohort.
- Feature‑first + Template‑driven architecture (containers.dev aligned) with sidecar browser option for iPad/phone.
- Preload multi‑repo lesson materials and frameworks; optional scaffolders for Next.js, etc.
- Policies at course/lesson scope (VS Code settings, extension packs, Chrome policies, port rules).
- Works with GitHub Codespaces (MVP) and supports self‑hosted later.

**Personas**
- **Instructor**: Assembles the stack, repos, and policies; clicks “Provision class.”
- **Student**: Opens the workspace, follows the lesson, codes, submits.
- **School admin**: Controls org‑wide limits, billing, compliance, audits.

---

## 2) High‑Level Architecture

```
+----------------------+      +----------------------+       +-----------------------+
|  Classroom Studio    |<---->|  Provider Connectors |<----->|  GitHub/Codespaces    |
|  Control Plane (SaaS)|      |  (GH, GHE, GitLab)   |       |  (or Self‑Hosted)     |
+----------+-----------+      +----------+-----------+       +-----------+-----------+
           |                              |                                 |
           |                             uses                              uses
           v                              v                                 v
  +------------------+         +------------------+              +----------------------+
  | Template Registry|         | Course Bundles   |              | Provisioning Engine  |
  | (Features & Tpl) |         | (YAML)           |              | (Codespaces or K8s)  |
  +------------------+         +------------------+              +----------------------+
           |                              |                                 |
           +------------------------------+---------------------------------+
                                          v
                              +-----------------------+
                              | Observability & Admin |
                              | (status, logs, costs) |
                              +-----------------------+
```

### Components
- **Template Registry**: Dev Container **Features** + **Templates** + optional prebuilt images.
- **Course Bundles**: Declarative YAML describing repos, template, options, policies, secrets, and roster.
- **Provisioning Engine**:
  - **MVP (GitHub Codespaces)**: Uses `devcontainer.json` + Compose + Codespaces settings to pre‑clone repos and start sidecars. Prebuilds optional.
  - **Self‑hosted (phase 2)**: K8s runner that uses the Dev Container CLI to build/attach environments; ingress + auth + storage.
- **Provider Connectors**: OAuth to GitHub, org install for class repos, Classroom roster import (later), secrets sync.
- **Observability/Admin**: Per student workspace status, port map, costs/quotas, recycling.

---

## 3) Spec‑Aligned Building Blocks

### 3.1 Features (tooling only)
- `supabase-cli` — installs CLI; optional helper scripts; **does not** start services.
- `chrome-cdp` — headless Chrome + DevTools port.
- `agent-tooling-clis` — optional AI CLIs (Codex/Claude/Gemini).
- `docker-in-docker-plus` — safe defaults for Docker workflows.
- `cuda-lite` — installs CUDA libs if GPU; no‑op otherwise.
- `workspace-manifest` — installs `ws-clone` & `ws-update` helpers (no auto‑clone).

### 3.2 Templates (flavours)
- `web` — Node + pnpm + Chrome CDP + Supabase CLI.
- `nextjs-supabase` — adds scaffold options (Next.js version, TS, App Router, auth).
- `classroom-studio-webtop` — **primary tooling container + webtop sidecar** for GUI Chrome via browser (iPad/phone‑friendly). Chrome policies mounted from JSON.
- `classroom-studio-cdp` — lightweight classroom without GUI desktop, still mobile‑usable via DevTools front‑end.

### 3.3 Stacks (optional)
Compose bundles that wire common sidecars (db, realtime, webtop) usable by Templates.

---

## 4) Course Bundle (YAML) — Declarative Class Config

> Instructors define a course once. Control Plane validates and provisions per student.

```yaml
course:
  id: cs101-fall-2025
  title: "CS101 – Modern Web Foundations"
  owner_org: airnub-labs
  template: classroom-studio-webtop@1.0.0
  templateOptions:
    webtopPort: 3001
    policyMode: managed
    chromePoliciesPath: .devcontainer/policies/managed.json
    scaffold: false

  repositories:
    # Codespaces pre-clone (preferred) + fallback manifest
    - repo: airnub-labs/lesson-starter
      ref: main
      clonePath: Lessons/01-starter
    - repo: airnub-labs/lesson-api
      ref: main
      clonePath: Lessons/01-api

  workspaceManifest: .devcontainer/workspace.repos.yaml  # optional

  vscode:
    extensions:
      - esbenp.prettier-vscode
      - dbaeumer.vscode-eslint
    settings:
      editor.tabSize: 2
      files.eol: "\n"

  policies:
    chromeManagedJSON: .devcontainer/policies/managed.json

  secrets:                      # resolved at provision time
    SUPABASE_URL: secret:supabase_url
    SUPABASE_ANON_KEY: secret:supabase_anon

  roster:
    source: csv                  # csv, github-classroom, sso
    path: ./roster/cs101.csv

  lifecycle:
    idleStopMinutes: 30
    maxRuntimeHours: 6
    retentionDays: 7
    schedule:
      startAt: "2025-11-01T09:00:00Z"
      endAt:   "2025-12-20T17:00:00Z"
```

**Behavior**
- **Template** selected with pinned version; options propagate into `devcontainer.json`/Compose.
- **Repos** cloned via Codespaces `customizations.codespaces.repositories`; fallback uses `workspace-manifest + ws-clone` in `postCreateCommand`.
- **Policies** mounted into sidecar (`/etc/opt/chrome/policies/managed`).
- **Secrets** are mapped at provision time from the org/tenant secret store.
- **Roster** produces a **workspace per student** with deterministic naming and labels.

---

## 5) Provisioning (MVP: GitHub Codespaces)

1. Instructor authenticates to GitHub and selects org/repos.
2. Control Plane validates template + options + repos + secrets.
3. For each student in **roster**:
   - Create a Codespace from the course repo (or a seeded template repo).
   - Inject `devcontainer.json` (Template payload) and `compose.yaml`.
   - Set `customizations.codespaces.repositories` for additional repos.
   - Apply environment variables/secrets at workspace scope.
   - Start Codespace; optional **prebuild** used if configured.
4. Track URLs, ports, and status in the Admin dashboard.

**Notes**
- Ports are private by default in Codespaces (auth gated). Webtop/DevTools appear as labeled ports.
- Per‑student overrides (accommodations) can be added (memory/time).

---

## 6) Provisioning (Phase 2: Self‑Hosted Option)

- **Runtime**: K8s + Dev Container CLI runner
  - Build Template into image; run primary container and sidecars (Compose translated to K8s).
  - Ingress with TLS + IdP (OIDC/SAML) to expose webtop/CDP ports.
  - Ephemeral PVCs per student with life‑cycle policies.
- **Access**:
  - VS Code Remote Containers over SSH/Web.
  - Built‑in browser desktop (webtop) for tablets/phones.
- **Secrets**: Vault or K8s Secrets; injected at pod creation.

---

## 7) Policies & Controls

- **VS Code**: extension set + settings via Template `customizations.vscode`.
- **Chrome** (webtop): JSON policies mount for managed classrooms (popups, password manager, sign‑in, etc.).
- **Ports**: annotate in Template with labels and visibility; blocklist open/public exposure.
- **Resources**: `hostRequirements` in `devcontainer.json` for memory/CPU hints; classroom‑level quotas.
- **Runtime controls**: idle stop, auto sleep, session cap, retention cleanup.

---

## 8) Multi‑Repo Strategy

- **Codespaces path**: `customizations.codespaces.repositories` (best UX).
- **Fallback**: `workspace.repos.yaml` + `ws-clone` helper (idempotent) in `postCreateCommand`.
- **Optional Feature**: `workspace-manifest` installs helpers only; Template drives behavior.

Manifest example:
```yaml
workspace:
  root: /workspaces
  defaultRef: main
repos:
  - url: https://github.com/airnub-labs/lesson-starter.git
    path: Lessons/01-starter
    ref: main
    depth: 1
  - url: git@github.com:airnub-labs/lesson-api.git
    path: Lessons/01-api
    ref: main
    sparse: ["packages/ui", "apps/web"]
```

---

## 9) Templates & Features — File Structure

```
features/
  supabase-cli/
  chrome-cdp/
  agent-tooling-clis/
  docker-in-docker-plus/
  cuda-lite/
  workspace-manifest/

templates/
  web/
  nextjs-supabase/
  classroom-studio-webtop/
  classroom-studio-cdp/

stacks/
  full-web-lab/

images/  (optional prebuilt)
  dev-base/
  dev-web/

.github/workflows/
  publish-features.yml
  test-features.yml
  build-images.yml
  test-templates.yml

docs/
  SPEC-ALIGNMENT.md
  CATALOG.md
  EDU-SETUP.md
  SECURITY.md
  OPERATIONS.md
  BILLING.md
  API.md
```

---

## 10) Example Template: `classroom-studio-webtop`

**`devcontainer.json` (payload)**
```json
{
  "name": "Classroom Studio (tooling + webtop)",
  "dockerComposeFile": ["./compose.yaml"],
  "service": "dev",
  "runServices": ["dev", "webtop"],
  "features": {
    "../../../../features/supabase-cli": {},
    "../../../../features/agent-tooling-clis": { "installCodex": true }
  },
  "forwardPorts": [3001],
  "portsAttributes": { "3001": { "label": "Desktop (webtop)", "requireLocalPort": false } },
  "customizations": {
    "codespaces": {
      "repositories": [
        { "repository": "airnub-labs/lesson-starter", "ref": "main", "clonePath": "Lessons/01-starter" }
      ]
    },
    "vscode": {
      "extensions": ["esbenp.prettier-vscode", "dbaeumer.vscode-eslint"],
      "settings": { "editor.tabSize": 2 }
    }
  },
  "postCreateCommand": ".devcontainer/postCreate.sh",
  "remoteUser": "vscode"
}
```

**`compose.yaml`**
```yaml
services:
  dev:
    image: ghcr.io/airnub-labs/dev-web:ubuntu24.04-node24-pnpm10-v1.3.0
    user: "vscode"
    volumes:
      - ..:/workspaces:cached
    shm_size: "2gb"

  webtop:
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - CUSTOM_USER=vscode
    volumes:
      - ..:/workspace
      - ./.devcontainer/policies:/etc/opt/chrome/policies/managed:ro
    ports:
      - "3001:3000"
    shm_size: "2gb"
```

**`postCreate.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail
# Optional: clone fallback for non-Codespaces
if [ -f .devcontainer/workspace.repos.yaml ]; then
  if command -v ws-clone >/dev/null 2>&1; then
    ws-clone .devcontainer/workspace.repos.yaml || true
  fi
fi
```

---

## 11) API Surface (Control Plane)

- **Course Packs**
  - `POST /courses` — create/update course bundle (YAML upload)
  - `POST /courses/{id}/provision` — provision N student workspaces
  - `POST /courses/{id}/recycle` — stop & clean workspaces
  - `GET /courses/{id}/status` — per student status/URLs

- **Templates & Features**
  - `GET /catalog/templates` — list versions/inputs
  - `GET /catalog/features` — list features and options

- **Rosters**
  - `POST /rosters/import` — CSV/GitHub Classroom

- **Secrets**
  - `POST /secrets` — bind named secrets at course scope

- **Auth & RBAC**
  - GitHub OAuth for instructor; role: instructor/admin/viewer

---

## 12) Observability & Cost Controls

- **Workspace status**: ready, building, running, idle, stopped.
- **Metrics**: build time, runtime hours, last activity, port map.
- **Budget**: caps per course; auto sleep after `idleStopMinutes`.
- **Logs**: build logs and `postCreate` output per student for quick triage.

---

## 13) Security & Compliance

- No secrets in Features; inject at provision time via provider secrets.
- Ports private by default; explicit opt‑in to public if ever needed.
- Chrome policies via read‑only mount; instructor can manage JSON without admin skills.
- Optionally integrate school SSO for student identity; map to GitHub accounts.

---

## 14) Roadmap

**v0.1 (MVP)**
- Codespaces provider, Template registry, Course bundles, roster CSV, Secrets mapping, webtop sidecar, status dashboard.

**v0.2**
- Self‑hosted K8s runner; Vault integration; granular quotas; artifact cache.

**v0.3**
- Assignment flows: open/submit; automated grading hooks; analytics per lesson; per‑student diff & replay.

**v1.0**
- Policy‑as‑code packs; curriculum marketplace; LTI integration; multi‑provider federation.

---

## 15) Naming & UX Suggestions

- Product: **Classroom Studio**
- Templates: **Classroom Studio — Webtop**, **Classroom Studio — CDP**, **Next.js + Supabase**
- “Lesson Packs”: pre‑curated repo sets + settings + policies.
- 1‑click “Start Class” button that provisions the cohort and returns a table of student URLs (and Live Share links, if desired).

---

## 16) Acceptance Criteria (Instructor Experience)

- Create a course from YAML or UI wizard.
- Select Template + Features, set options, choose repos, add policies, upload roster.
- Click **Provision**; within minutes each student has:
  - A running workspace with all repos pre‑cloned.
  - A labeled **Desktop (webtop)** port or **Chrome DevTools** port ready.
  - VS Code settings/extensions as configured.
  - Secrets available and working; Supabase CLI ready if used.
- Instructor sees a live status table, can open any student’s workspace (assist mode, rights‑controlled), and enforce idle shutdown.

