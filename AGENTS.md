# AGENTS.md (v0.2) — Guardrails & Playbook for Coding Agents

> **Repository mode:** one repo that hosts the **Catalog** (Features/Templates/Images/Docs) and a **Workspaces** area with multiple workspace variants (`webtop`, `novnc`). GitHub **Codespaces** works out‑of-the-box via a **root `.devcontainer` bridge** that points at the default variant and exposes others via the picker.
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

## 1) Non-negotiable Invariants

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
- `cuda-lite@1` — optional GPU libs; must succeed as no-op without GPU.

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

## 9) Pre-merge Checklist

- [ ] `devcontainer build` passes for all changed variants.
- [ ] Ports reachable: `9222`, `3001`/`6080`, `6379` (and Studio `54323` when started).
- [ ] Blueprint parses and clones idempotently.
- [ ] Docs updated (`docs/CATALOG.md`, `docs/WORKSPACE-ARCHITECTURE.md`).

---
