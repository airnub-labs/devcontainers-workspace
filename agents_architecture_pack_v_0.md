# AGENTS.md (v0.2) — Guardrails & Playbook for Coding Agents

> **Repository mode:** one repo that hosts the **Catalog** (Features/Templates/Images/Docs) and a **Workspaces** area with multiple workspace variants (`webtop`, `novnc`). GitHub **Codespaces** works out‑of‑the‑box via a **root `.devcontainer` bridge** that points at the default variant and exposes others via the picker.
>
> **Prime directives:** (1) Keep Catalog and Workspaces concerns separate. (2) Never regress the ability to open a workspace and get a working devcontainer with Node, Supabase CLI, Redis, a browser desktop (webtop or noVNC), and Chrome CDP.

---

## 0) Directory Map & Ownership

| Path | Role | Owner | Allowed Agent Changes |
|---|---|---|---|
| `.devcontainer/**` | **Root Codespaces bridge** configs (default + picker variants) | Workspaces | ✅ Keep simple bridge that delegates to `workspaces/<variant>`. |
| `features/*` | Dev Container **Features** (install tools only) | Catalog | ✅ Add/modify features (idempotent installers). ❌ No services, no secrets. |
| `templates/*` | Dev Container **Templates** (compose sidecars, options) | Catalog | ✅ Add/modify templates; multi-container wiring. |
| `images/*` | Base/prebuilt images | Catalog | ✅ Dockerfiles & READMEs; pin digests in consumers. |
| `docs/*` | Human reference + spec alignment | Docs | ✅ Update freely; keep in sync with code. |
| `workspaces/<variant>/.devcontainer/*` | **Materialized** devcontainer per workspace | Workspaces | ✅ Sync with templates; keep variant deltas minimal and documented. |
| `workspaces/<variant>/*.code-workspace` | VS Code workspace lens | Workspaces | ✅ Keep curated folders only. |
| `workspaces/<variant>/workspace.blueprint.json` | Repo clone manifest | Workspaces | ✅ Update repo list/refs; **never** commit cloned repos. |
| `workspaces/_shared/*` | Shared workspace resources (e.g., `supabase/`) | Workspaces | ✅ Maintain; keep lightweight. |
| `apps/` | Cloned project repos (ignored by Git) | Workspaces | ❌ Never commit; cloned on `postCreate`. |

**Rule of thumb:** Features install tooling; Templates orchestrate services; Workspaces hold the concrete `.devcontainer/` + `.code-workspace` and dynamic repo cloning.

---

## 1) Non‑negotiable Invariants

1. **One container per workspace** (VS Code constraint). Different variants → separate folders under `workspaces/`.
2. **Features ≠ Services**: installers cannot start daemons; no Docker calls; idempotent.
3. **No secrets in Git**: rely on Codespaces/Actions secrets only.
4. **Ports & Services (must remain reachable/consistent):**
   - Chrome CDP: **9222** (`/json/version`).
   - Webtop desktop: **3001**.
   - noVNC desktop: **6080** (audio optional: **6081**).
   - Redis: **6379**.
   - Supabase Studio (when local stack is started): **54323**.
5. **Supabase local** is managed by the **CLI** (not embedded compose unless explicitly required by a template flavor).
6. **Codespaces safety**: avoid `privileged: true`; prefer sidecars to DinD.
7. **Idempotency**: `postCreate`/`postStart` must be safe to re-run.

---

## 2) Current Workspace Variants

- `workspaces/webtop/` — desktop via **linuxserver/webtop** + CDP.
- `workspaces/novnc/` — desktop via **noVNC** image + CDP.

Each variant includes:
- `.devcontainer/devcontainer.json` with `workspaceMount` to repo root and labeled `forwardPorts`.
- `.devcontainer/compose.yaml` composing `dev` + GUI sidecar + `redis`.
- `postCreate.sh` (clones from `workspace.blueprint.json`) and `postStart.sh`.
- `workspace.blueprint.json` (repos cloned into `/apps`).
- `*.code-workspace` pointing at `../../apps`, `../../docs`, `../../workspaces/_shared/supabase`.

---

## 3) Catalog Contracts: Templates & Features

### 3.1 Features (IDs & options)

- `supabase-cli@1` — `{ manageLocalStack?: boolean, version?: string }`
- `chrome-cdp@1` — `{ channel?: "stable"|"beta", port?: number }`
- `agent-tooling-clis@1` — `{ installCodex?: boolean, installClaude?: boolean, installGemini?: boolean }`
- `docker-in-docker-plus@1` — *(meta-feature)* buildx/bootstrap; no options.
- `cuda-lite@1` — optional GPU libs; must succeed as no‑op without GPU.

**Feature rules:** provide `devcontainer-feature.json` with option schema; `install.sh` idempotent; no services.

### 3.2 Templates

- `templates/classroom-studio-webtop` — canonical multi-container template. Workspaces materialize from this and then tweak minimal GUI deltas.

**Template rules:** own `dockerComposeFile`, `runServices`, sidecars, policy mounts, `portsAttributes`. Expose options via `devcontainer-template.json`.

---

## 4) Workspace Blueprint (schema)

`workspaces/<variant>/workspace.blueprint.json`:

```json
{
  "repos": [
    { "url": "https://github.com/airnub-labs/million-dollar-maps", "path": "apps/million-dollar-maps", "ref": "main" }
  ]
}
```

- `url`: git clone URL (required)
- `path`: target path relative to repo root (required)
- `ref`: optional branch/tag/commit

`postCreate.sh` must ensure pnpm store perms, clone if missing, and print versions (`node`, `pnpm`, `supabase`).

---

## 5) Agent Playbook (Common Tasks)

**A. Add a CLI to `agent-tooling-clis`** → add option flag in feature schema; update `install.sh`; update `docs/CATALOG.md` matrix.

**B. Sync a workspace with latest template** → copy `.template/.devcontainer/*` to the variant folder, restore GUI deltas, build, and commit.

**C. Add a new workspace variant** → seed from template, adjust compose for GUI sidecar, add blueprint + hooks + workspace file, test & doc.

**D. Upgrade Supabase CLI feature** → bump default/pin; rebuild; update `docs/shared-supabase.md`.

**E. Pin image digests** → replace tags with `@sha256:…` in compose; document in `docs/CATALOG.md`.

---

## 6) CI & Regression Gates

**Features**: schema validate; ephemeral build; run `install.sh`; assert binaries.

**Templates**: materialize to temp; `devcontainer build` must pass.

**Workspaces (per variant)**:
- `devcontainer build` passes.
- Health:
  - `curl -fsSL http://localhost:9222/json/version` OK.
  - Desktop HTTP: `3001` (webtop) **or** `6080` (noVNC).
  - `redis-cli -h 127.0.0.1 -p 6379 PING` → `PONG`.
  - Optional: `supabase start` then Studio at `54323`.

Artifacts: attach SBOM (CycloneDX) + provenance when building images; pin digests.

---

## 7) Versioning & Tagging

- **Features**: semver, breaking installer = **MAJOR**.
- **Templates**: semver, option/compose schema changes = **MINOR/MAJOR**.
- **Workspaces**: no semver; conventional commits with clear PR titles.

---

## 8) Don’ts (Hard Blocks)

- ❌ Start services in feature installers.
- ❌ Commit anything under `/apps`.
- ❌ Change standard ports without updating labels and docs.
- ❌ Remove CDP or GUI access from variants.

---

## 9) Pre‑merge Checklist

- [ ] `devcontainer build` passes for all changed variants.
- [ ] Ports reachable: `9222`, `3001`/`6080`, `6379` (and Studio `54323` when started).
- [ ] Blueprint parses and clones idempotently.
- [ ] Docs updated (`docs/CATALOG.md`, `docs/WORKSPACE-ARCHITECTURE.md`).

---

---

# docs/WORKSPACE-ARCHITECTURE.md (v0.2)

## Overview
The **Workspaces** area hosts multiple **variants**, each with its own `.devcontainer/` and `.code-workspace`. A **root `.devcontainer` bridge** lets Codespaces pick a default (webtop) or select another (novnc) at creation time.

```
workspaces/
  webtop/
    .devcontainer/
    airnub-webtop.code-workspace
    workspace.blueprint.json
    postCreate.sh
    postStart.sh
  novnc/
    .devcontainer/
    airnub-novnc.code-workspace
    workspace.blueprint.json
    postCreate.sh
    postStart.sh
  _shared/
    supabase/
apps/           # cloned on demand; ignored by Git
.devcontainer/  # root bridge: default + picker profiles
```

### Mounts
All variants mount the repo root into the container even when opened from a subfolder:

```json
{
  "workspaceMount": "source=${localWorkspaceFolder}/../..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces"
}
```

### Services & Ports
- `dev` primary: Node 24 + pnpm + CLIs; **CDP 9222**.
- `redis` sidecar: **6379**.
- GUI sidecar per variant: `webtop` (**3001**) or `novnc` (**6080**, audio optional **6081**).
- Supabase Studio (via CLI): **54323** when started.

### Dynamic projects (blueprint)
`workspace.blueprint.json` defines repos to clone into `/apps` during `postCreate`. Workspaces’ `*.code-workspace` points generically to `/apps`, so no edits are needed when repos change.

### Security & isolation
- No secrets in Git; consume Codespaces/Actions secrets.
- Avoid privileged containers; prefer sidecars.

---

# docs/CATALOG-ARCHITECTURE.md (v0.2)

## Components
- **Features** (`features/*`): reusable installers; idempotent, no services, no secrets.
- **Templates** (`templates/*`): multi-container orchestration and options.
- **Images** (`images/*`): prebuilt bases; multi‑arch publication.

### Feature principles
- `devcontainer-feature.json` with schema + defaults.
- `install.sh` idempotent; no Docker; non‑root friendly.
- Example feature IDs: `supabase-cli@1`, `chrome-cdp@1`, `agent-tooling-clis@1`, `docker-in-docker-plus@1`, `cuda-lite@1`.

### Template principles
- Own `dockerComposeFile`, `runServices`, sidecars, port labels.
- Options via `devcontainer-template.json`.
- Workspaces **materialize** the template; VS Code does not pull templates at open time.

### Images
- Publish to GHCR with provenance + SBOM; consumers may **pin digests** in compose files.

---

# docs/AGENT-PLAYBOOK.md (v0.2)

## Create a new workspace variant
1. `mkdir -p workspaces/<name>/.devcontainer`.
2. Seed from `templates/classroom-studio-webtop/.template/.devcontainer/`.
3. Adjust compose (swap GUI sidecar, ports, labels); keep `dev` + `redis`.
4. Add `workspace.blueprint.json`, `postCreate.sh`, `postStart.sh`, and `<name>.code-workspace`.
5. Build & health-check; document in `docs/WORKSPACE-ARCHITECTURE.md`.

## Update a feature
1. Edit `features/<id>/devcontainer-feature.json` option schema + `install.sh`.
2. Update `features/<id>/README.md` and `docs/CATALOG.md`.
3. Run feature tests.

## Sync workspace from template
1. Copy template payload into `workspaces/<variant>/.devcontainer/`.
2. Restore variant-specific deltas.
3. `devcontainer build`; open PR with summary + checklist.

## Add a CLI to `agent-tooling-clis`
1. Add option flag in schema; implement conditional install.
2. Update docs; ensure idempotency.

## Pin image digest
1. Replace tag with `@sha256:…` in compose; add to `docs/CATALOG.md` matrix.

---

# docs/TEMPLATE-SYNC.md (v0.2)

## Manual sync
1. Pick template tag/version (e.g., `classroom-studio-webtop@1.3.0`).
2. Copy `.template/.devcontainer/*` → `workspaces/<variant>/.devcontainer/`.
3. Re-apply variant deltas (GUI service, ports).
4. Rebuild; run regression checks; commit with `chore(workspaces): sync <variant> with template vX.Y.Z`.

## Optional GitHub Action (sketch)
- Trigger: changes in `templates/classroom-studio-webtop/.template/.devcontainer/**`.
- Job: for each `workspaces/*`, open PR with updated payload + run smoke tests (ports, CDP, Redis, Studio when started).

---

# docs/REGRESSION-CHECKS.md (v0.2)

**Features**
- Validate JSON schema.
- Build ephemeral container; run `install.sh`; assert binary presence and versions.

**Templates**
- Materialize to temp; `devcontainer build` must pass.

**Workspaces (each variant)**
- Build success.
- Health probes:
  - `curl -fsSL http://localhost:9222/json/version` returns JSON.
  - Desktop reachable (`3001` webtop / `6080` novnc).
  - `redis-cli -h 127.0.0.1 -p 6379 PING` → `PONG`.
  - Optional: `supabase start`; Studio on `54323`.
- No files under `/apps` in Git history.

**Codespaces root bridge**
- Default config (webtop) works from repo root.
- Picker lists both `webtop` and `novnc` configs.

---

# docs/CODESPACES-BRIDGE.md (v0.2)

## Purpose
Ensure “Create codespace” at repo root uses a working configuration (default **webtop**) and exposes other variants via the picker, while keeping real devcontainer payloads under `workspaces/<variant>/.devcontainer`.

## Files
- `.devcontainer/devcontainer.json` → default (webtop) delegating to `../workspaces/webtop/.devcontainer/compose.yaml` and hooks under `workspaces/webtop/`.
- `.devcontainer/webtop/devcontainer.json` → picker profile for webtop.
- `.devcontainer/novnc/devcontainer.json` → picker profile for novnc.

## Behavior
- Default codespace = webtop.
- “Configure and create” shows **webtop**/**novnc** options.
- All profiles mount repo root to `/workspaces` so subfolder workspaces can access shared materials.

---

# docs/CATALOG.md (matrix excerpt, v0.2)

## Workspace Variants

| Variant | GUI | CDP | Redis | Supabase local | Notes |
|---|---|---:|---:|---:|---|
| `workspaces/webtop` | linuxserver/webtop:ubuntu-xfce | 9222 | 6379 | CLI-managed | Desktop at 3001 |
| `workspaces/novnc` | dorowu/ubuntu-desktop-lxde-vnc | 9222 | 6379 | CLI-managed | Desktop at 6080 (audio opt. 6081) |

## Feature Matrix (selected)

| Feature | Default Options | Provides |
|---|---|---|
| `supabase-cli@1` | `manageLocalStack: true` | `supabase` binary + helpers |
| `chrome-cdp@1` | `channel: stable`, `port: 9222` | Headless Chrome + CDP |
| `agent-tooling-clis@1` | `installCodex: true` | Agent CLIs (codex/claude/gemini opts) |
| `docker-in-docker-plus@1` | — | buildx bootstrap |
| `cuda-lite@1` | — | Minimal CUDA libs (no-op w/o GPU) |

---

**End of v0.2 Pack**

