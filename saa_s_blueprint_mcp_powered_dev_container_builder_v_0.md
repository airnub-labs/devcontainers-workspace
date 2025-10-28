# SaaS Blueprint — MCP‑powered DevContainer Builder (v0.1)

**Goal**: Turn your repo’s Features/Templates/Images into a multi‑tenant SaaS where users (devs, schools) compose custom devcontainers, spawn workspaces on demand (Codespaces or self‑hosted), and optionally let an LLM seed new VS Code workspaces with starter projects and data — governed via **MCP** (Model Context Protocol) toolchains for safe, auditable automation.

> Designed to reuse your existing structure: `features/*`, `templates/*`, `images/*`, CI to publish OCI features + GHCR images, and the sidecar webtop pattern for iPad/phone Chrome DevTools.

---

## 1) Why MCP here

MCP gives the LLM **typed, permissioned tools** so “chat‑to‑workspace” actions are explicit and auditable:

* **Discoverable tools**: list Features, Templates, versions, and compatible options.
* **Composable actions**: create a Workspace Blueprint, generate a repo, pin digests, open PRs.
* **Guardrails**: every destructive action requires an explicit capability (e.g., `repos.create`, `build.publish`).
* **Traceability**: logs + provenance for each tool call (SLSA/Sigstore alignment).

This is superior to brittle prompt‑only flows and cleanly maps to your repo’s modular layout.

---

## 2) High‑level user stories

1. **Self‑serve devcontainer**: “Give me Node 24 + pnpm + Supabase CLI + Chrome CDP.” → Picks a Template, selects Features + versions, gets a reproducible devcontainer (locked to digests) and one‑click launch.
2. **Classroom lab**: Educator picks `classroom-studio-webtop`, adds Chrome policies, a curated repo list, and time‑boxed quotas. Students click a link; everything works in a browser/iPad.
3. **Ad‑hoc Workspace via LLM**: “Create a Next.js 15 + Supabase workspace, scaffold auth, and preload a sample DB + seed data.” The LLM uses MCP tools to scaffold, commit, and open a workspace.
4. **Org presets**: Platform admin publishes curated stacks (“Web Fundamentals”, “AI Agents 101”) as sharable presets with locked versions.

---

## 3) Architecture (overview)

**Frontend (Next.js)** ↔ **API Gateway** ↔ **Orchestrator** →

* **MCP Servers** (tool providers):
  * `devcontainers.registry`: list/install **Features** (OCI in GHCR)
  * `devcontainers.templates`: list/materialize **Templates** (git tag/OCI index)
  * `images.builder`: build/push **Images** (BuildKit + cosign)
  * `github.admin`: create repos, branches, PRs, secrets via GitHub App
  * `scaffolder`: run language scaffolds (create‑next‑app, etc.) in sandbox
  * `secrets.vault`: short‑lived creds via OIDC
  * `datasets.ingest`: fetch/normalize seed datasets
  * `workspaces.launcher`: provision Codespaces / self‑hosted workspaces
  * `policy.guard`: enforce org policy (allow‑lists, version caps)

* **Runtimes**:
  * **Codespaces** (first‑class)
  * **Self‑hosted k8s workspaces** (openvscode‑server or code‑server) with **webtop** sidecar for GUI DevTools

* **Registries**: GHCR for features/images; optional OCI index for templates
* **Provenance**: cosign/SLSA attestations; SBOMs (CycloneDX) stored and queryable

---

## 4) Reuse from your repo (alignment)

* **Features**: `supabase-cli`, `chrome-cdp`, `agent-tooling-clis`, `docker-in-docker-plus`, `cuda-lite` → publish as OCI artifacts.
* **Templates**: `web`, `nextjs-supabase`, `classroom-studio-webtop` → kept as tag‑versioned payloads.
* **Images**: `dev-base`, `dev-web` → multi‑arch, pinned digests for fast starts.
* **CI**: keep/polish `publish-features.yml`, `test-features.yml`, `build-images.yml`, `test-templates.yml`.

---

## 5) Data model (core objects)

```yaml
# Workspace Blueprint (authoritative desired state)
apiVersion: v1
kind: WorkspaceBlueprint
metadata:
  name: nextjs-supabase-starter
spec:
  templateRef:
    name: classroom-studio-webtop    # or web / nextjs-supabase
    version: "1.3.0"
  features:
    - name: supabase-cli
      version: "1.2.0"
      options:
        manageLocalStack: true
    - name: agent-tooling-clis
      version: "0.4.0"
      options:
        installCodex: true
        installClaude: false
        installGemini: false
  image:
    ref: ghcr.io/airnub-labs/dev-web@sha256:...
  repos:
    - url: github.com/airnub-labs/seed-next-supa
      path: app
    - url: github.com/airnub-labs/edu-labs
      path: labs
  policies:
    chromePoliciesPath: .devcontainer/policies/managed.json
    network:
      forwardPorts: [9222, 3001]
  seeding:
    scaffolds:
      - type: nextjs
        version: "15"
        ts: true
        appRouter: true
        auth: true
    datasets:
      - url: https://example.com/sample.csv
        mountPath: data/sample.csv
    llmRecipes:
      - name: "add-tables-and-routes"
        promptRef: llm/recipes/add_tables.md
        outputs:
          - path: supabase/migrations/*.sql
          - path: app/src/app/(routes)/**
  runtime:
    provider: codespaces   # or selfhosted
    size: standard
    ttlHours: 24
```

*Other objects*: `FeatureIndex`, `TemplateIndex`, `WorkspaceInstance`, `SeedJob`, `Attestation` (SLSA), `SbomRecord`.

---

## 6) MCP servers (capabilities & contracts)

**A. devcontainers.registry**
- `listFeatures()` → `{ name, versions[], optionsSchema }[]`
- `materializeFeature({ name, version, options })` → OCI ref + install plan

**B. devcontainers.templates**
- `listTemplates()` → `{ name, versions[], optionsSchema, sidecars? }[]`
- `compose({ template, features[], options })` → produces `.devcontainer/` payload (json + compose + scripts)

**C. images.builder**
- `build({ dockerfileContext, args, baseImage })` → digest, SBOM, provenance
- `push({ imageRef })` → GHCR tag + cosign signature

**D. github.admin** (via GitHub App installation per tenant)
- `createRepo({ owner, name, private })`
- `commitTree({ repo, files[] })`
- `openPR({ base, head, title, body })`
- `setSecret({ repo, name, value|oidcRef })`

**E. workspaces.launcher**
- `startCodespace({ repo, devcontainerPath, machine })` → url, ports
- `startSelfHosted({ blueprint, clusterPool })` → ingress url, creds

**F. scaffolder** (sandboxed runner)
- `runScaffold({ kind, version, params })` → file tree diff

**G. datasets.ingest**
- `fetch({ url, checksum? })` → store → `mountPath`

**H. policy.guard**
- `validate({ blueprint })` → pass/fail + reasons (e.g., feature allow‑list, version caps)

Each server declares MCP **schemas** (JSON Schema) for inputs/outputs so the LLM can reliably chain tools.

---

## 7) Control plane flows

### Flow A — Configure & generate
1. User picks Template → selects Features/versions → UI renders option schemas.
2. API creates a `WorkspaceBlueprint` CR (YAML) and validates via `policy.guard`.
3. `devcontainers.templates.compose` emits a ready `.devcontainer/` payload.
4. `github.admin.createRepo` + `commitTree` push the payload + seed `README`.
5. Optional: `images.builder.build/push` to bake a prebuilt image for speed.

### Flow B — Launch workspace
1. User clicks **Launch** → `workspaces.launcher.startCodespace` (or self‑hosted) using the repo’s devcontainer.
2. Ports/labels from the template are auto‑forwarded (e.g., CDP 9222, webtop 3001).

### Flow C — LLM seeding
1. User asks: “Add Supabase schema + user profile page.”
2. Orchestrator prompts the LLM with the repo context and available MCP tools.
3. LLM calls `scaffolder` + `datasets.ingest` as needed → `github.admin.openPR` with changes, SBOM, and attestation attached.
4. Human approves PR; CI runs tests/lints and merges.

---

## 8) Security & multi‑tenancy

* **Boundary by design**: GitHub App per tenant; repo‑scoped tokens; least privilege.
* **Secrets**: OIDC‑minted short‑lived creds; Vault brokered by `secrets.vault`.
* **Isolation**: build jobs in ephemeral runners (Firecracker/VM‑based or k8s with gVisor); rate limits + quotas.
* **Supply chain**: cosign‑sign images/features; publish SBOM (CycloneDX) + SLSA attestation.
* **Policy**: feature allow‑list, template caps, max TTL for workspaces, outbound egress controls.

---

## 9) Classroom mode specifics

* **Preset blueprints** with locked versions and read‑only repos; per‑student fork on launch.
* **Time‑boxed** workspaces (TTL) auto‑suspend; storage quotas per student.
* **Web‑only**: prefer `classroom-studio-webtop` Template; Chrome policies mounted.
* **Roster & grading**: tie submissions to PRs against an instructor repo.

---

## 10) API sketch (REST)

```http
POST /v1/blueprints           # create from form or YAML
GET  /v1/blueprints/:id       # read
POST /v1/blueprints/:id/validate
POST /v1/blueprints/:id/materialize   # returns devcontainer payload
POST /v1/blueprints/:id/commit        # create repo + push
POST /v1/workspaces            # launch (codespaces|selfhosted)
POST /v1/workspaces/:id/stop
POST /v1/seeding/:repo/pr      # run LLM recipe + open PR
GET  /v1/catalog/features|templates|images
```

---

## 11) LLM “recipes” (seed automation)

* **Recipe structure**: prompt, required contexts, expected outputs, safety notes.
* Example: `llm/recipes/add_tables.md`
  * Inputs: ERD text, CSVs, feature flags
  * Tools allowed: `scaffolder`, `datasets.ingest`, `github.admin.openPR`
  * Outputs: SQL migrations, route files, tests

Recipes are versioned and reviewed like code; the MCP policy server ensures only approved tools are callable.

---

## 12) Build & provenance

* Build with **BuildKit** (cache mounts) → push to GHCR.
* Generate **SBOM** (Syft) + **SLSA v1.0** provenance; sign with **cosign**.
* Store artifact metadata and surface in the UI per workspace.

---

## 13) MVP scope (concrete)

* Catalog UI: list Templates/Features from GHCR + git tags.
* Blueprint editor (form + YAML tab) with validation.
* Materialize → repo commit → launch Codespace.
* One LLM recipe: Next.js + Supabase seed (auth + profile CRUD) via PR.
* Policy guardrails: org allow‑list; TTL; port exposure limits.

---

## 14) Roadmap (selected)

* Template **OCI index** + remote resolution.
* "Workspace Presets" marketplace (org‑scoped curations).
* Self‑hosted k8s **pool autoscaler** for class bursts.
* **Cost/usage** telemetry + showback per org/class.
* **Dataset vaults** with differential privacy for teaching sets.

---

## 15) Risks & mitigations

* **Codespaces quotas** → Offer self‑hosted fallback, prebuilt images to reduce minutes.
* **Prompt drift** in LLM recipes → tool‑first MCP flows, unit tests for recipes, PRs not direct writes.
* **Feature churn** → lock with digests; version matrices in `docs/CATALOG.md`.

---

## 16) Acceptance checks

- From a clean tenant, create a Blueprint → repo → launch workspace in <N> clicks.
- Port labels present (CDP/webtop) and reachable; Chrome policies mounted.
- LLM recipe produces a PR with migrations + routes; CI passes.
- Artifacts (image digest, SBOM link, provenance) attached to the workspace record.

---

## 17) Example outputs

### A. Generated `.devcontainer/devcontainer.json` (from Blueprint)

```json
{
  "name": "web + supabase + cdp",
  "image": "ghcr.io/airnub-labs/dev-web@sha256:...",
  "features": {
    "../features/supabase-cli": {
      "manageLocalStack": true
    },
    "../features/chrome-cdp": {
      "channel": "stable",
      "port": 9222
    },
    "../features/agent-tooling-clis": {
      "installCodex": true
    }
  },
  "forwardPorts": [9222, 3001],
  "portsAttributes": {
    "9222": { "label": "Chrome DevTools" },
    "3001": { "label": "Desktop (webtop)" }
  },
  "postCreateCommand": ".devcontainer/postCreate.sh"
}
```

### B. Compose sidecar (when template requires webtop)

```yaml
services:
  dev:
    image: ghcr.io/airnub-labs/dev-web@sha256:...
    volumes: ["..:/workspaces:cached"]
    shm_size: 2gb
  webtop:
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    volumes:
      - ..:/workspace
      - ./.devcontainer/policies:/etc/opt/chrome/policies/managed:ro
    ports:
      - "${WEBTOP_PORT:-3001}:3000"
```

---

### C. Teacher preset (compact YAML)

```yaml
apiVersion: v1
kind: WorkspaceBlueprint
metadata: { name: web-101-lab-week1 }
spec:
  templateRef: { name: classroom-studio-webtop, version: "1.3.0" }
  features:
    - { name: supabase-cli, version: "1.2.0" }
    - { name: chrome-cdp, version: "1.1.0", options: { channel: stable, port: 9222 } }
  repos:
    - { url: github.com/airnub-labs/web-101-starter, path: app }
  runtime: { provider: codespaces, ttlHours: 6 }
  policies: { chromePoliciesPath: .devcontainer/policies/edu-week1.json }
```

---

## 18) Implementation notes (fit to your repo)

* Keep Features small and idempotent; **never** start services in feature `install.sh`.
* Templates own multi‑container (webtop) and scaffolding logic; offer options not hard‑wires.
* Expose a machine‑readable **Catalog** (JSON) of features/templates/images for both UI and MCP servers.
* Add CI jobs that **materialize** each template to a temp dir and `devcontainer build` it (your current direction is perfect).

---

**Bottom line**: Yes — your repo design is a strong foundation for a SaaS with MCP‑driven, user‑composable devcontainers and LLM‑seeded workspaces. The blueprint above shows the concrete contracts and artifacts to wire it up with guardrails, provenance, and a classroom‑friendly UX. 

