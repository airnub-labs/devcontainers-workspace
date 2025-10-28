# Refactor repo to Dev Containers Features + Templates (with sidecar browser), add CI, and ship versioned GHCR artifacts

## Repository

* Workspace root: `<repo root of airnub-labs/vscode-meta-workspace-internal branch codex/add-commands-for-supabase-scripts>`

## High-level goals

1. Migrate all “install-this-tool” shell scripts (Supabase CLI, Codex CLI, Claude CLI, Gemini CLI, etc.) into **spec-compliant Dev Container Features**.
2. Create **Dev Container Templates** (“flavours”) that combine those Features, including:

   * `nextjs-supabase` (scaffold-capable option)
   * `web` (Node + pnpm + Chrome CDP + Supabase CLI, no GUI desktop)
   * `classroom-studio-webtop` (primary tooling container + webtop/noVNC sidecar for iPad/phone Chrome DevTools)
3. Provide optional **prebuilt images** for fast starts (multi-arch, GHCR).
4. Add CI to publish Features (OCI) + build images (GHCR) + test Templates.
5. Document how to choose frameworks/versions via Template options; keep Features focused on tooling (not project scaffolding).

## Guardrails (spec alignment)

* **Features**: OCI-distributed units with `devcontainer-feature.json` + `install.sh`, idempotent, non-root friendly. No lifecycle hooks in features.
* **Templates**: include `.template/.devcontainer/devcontainer.json` (+ `compose.yaml` if needed). Templates distribute via git tags (optionally OCI index).
* **Multi-container**: Use Template payload `devcontainer.json` with `dockerComposeFile`, `service` (primary), and `runServices` for sidecars (webtop). No features on sidecars.

## Target layout (create/replace as needed)

```
features/
  supabase-cli/
  chrome-cdp/
  agent-tooling-clis/
  docker-in-docker-plus/
  cuda-lite/

templates/
  web/
  nextjs-supabase/
  classroom-studio-webtop/

images/
  dev-base/
  dev-web/

scripts/
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
  MIGRATION.md
  MAINTAINERS.md

VERSIONING.md
```

## Features to implement

### A) `features/supabase-cli`

**devcontainer-feature.json**

* `id`: `supabase-cli`
* **options**

  * `version` (string, default `"latest"`)
  * `manageLocalStack` (boolean, default `false`) — if true, install helper scripts `sbx-start`, `sbx-stop`, `sbx-status` that call `supabase start/stop/status`.
  * `services` (string array, optional) — advisory; list desired Supabase services. Actual selection is done by CLI flags or template compose; document mapping in README.
  * `projectRef` (string, optional)
* **containerEnv**: `SUPABASE_PROJECT_REF` populated if provided.
* **installsAfter**: `["ghcr.io/devcontainers/features/common-utils"]`

**install.sh (idempotent)**

* Install Supabase CLI non-interactively.
* Detect `containerUser`; avoid breaking permissions; non-root friendly.
* If `manageLocalStack=true`, install helper scripts under `/usr/local/bin`.
* **Do not** run Docker here—Templates decide runtime topology.

### B) `features/chrome-cdp`

**devcontainer-feature.json**

* `id`: `chrome-cdp`
* **options**

  * `channel` (enum: `stable|beta`, default `stable`)
  * `port` (integer, default `9222`)
* **containerEnv**: `CDP_PORT` = `${port}`
* **installsAfter**: `["ghcr.io/devcontainers/features/common-utils"]`

**install.sh (idempotent)**

* Install Google Chrome for the specified channel.
* Provision a lightweight supervisor (e.g., s6/supervisord) to run:
  `google-chrome --headless --remote-debugging-address=0.0.0.0 --remote-debugging-port=$CDP_PORT about:blank`
* Don’t expose ports here; Template handles `forwardPorts`.

### C) `features/agent-tooling-clis`

**devcontainer-feature.json**

* `id`: `agent-tooling-clis`
* **options**

  * `installCodex` (boolean, default `true`)
  * `installClaude` (boolean, default `false`)
  * `installGemini` (boolean, default `false`)
  * `versions` (object with optional keys `codex`, `claude`, `gemini`, default `latest`)

**install.sh (idempotent)**

* Conditionally install CLIs (npm/pip/curl). Add PATH shims. No secrets embedded.

### D) `features/docker-in-docker-plus`

* Thin meta-feature that ensures buildx, sane `/dev/shm`, and documents limitations under Codespaces.

### E) `features/cuda-lite`

* Detect GPU presence. Install minimal CUDA libs if present; succeed no-op if not. Document Codespaces fallback.

---

## Templates to implement

### 1) `templates/web`

**devcontainer-template.json**

* **options**

  * `usePrebuiltImage` (boolean, default `true`)
  * `chromeChannel` (`stable|beta`, default `stable`)
  * `cdpPort` (number, default `9222`)

**.template/.devcontainer/devcontainer.json**

* If `usePrebuiltImage=true` → `"image": "ghcr.io/airnub-labs/dev-web:<tag>"`
* Else use a local `build` with Args.
* **features**

  * `../../../../features/chrome-cdp`: `{ "channel": "${templateOption:chromeChannel}", "port": "${templateOption:cdpPort}" }`
  * `../../../../features/supabase-cli`: {}
* `forwardPorts`: `[${templateOption:cdpPort}]`
* `portsAttributes`: label `Chrome DevTools`.
* `postCreateCommand`: `.devcontainer/postCreate.sh`

### 2) `templates/nextjs-supabase`

**devcontainer-template.json**

* **options**

  * `scaffold` (boolean, default `false`)
  * `nextVersion` (string, default `"15"`)
  * `ts` (boolean, default `true`)
  * `appRouter` (boolean, default `true`)
  * `auth` (boolean, default `true`)

**.template/.devcontainer/devcontainer.json**

* Same features as `web` (+ optionally `agent-tooling-clis`).

**.template/.devcontainer/postCreate.sh**

* If `scaffold=true` **and** no `package.json` present:

  * Run a non-interactive `create-next-app` pinned to `nextVersion` (TS/App Router flags as per options), then add `@supabase/supabase-js` and optional auth packages.
* Else no-op.
* **Note**: framework scaffolding happens in Templates (not Features).

### 3) `templates/classroom-studio-webtop`

> (Rename from `school-full` for clarity. You may create more flavours later: `classroom-studio-cdp`, `classroom-studio-nextjs-supabase`, etc.)

**devcontainer-template.json**

* **options**

  * `policyMode` (enum: `none|managed`, default `none`)
  * `webtopPort` (number, default `3001`)
  * `chromePolicies` (string, default `.devcontainer/policies/managed.json`)

**.template/.devcontainer/devcontainer.json**

* `dockerComposeFile`: `["./compose.yaml"]`
* `service`: `"dev"`
* `runServices`: `["dev","webtop"]`
* **features on `dev` only**

  * `supabase-cli`
  * `agent-tooling-clis` (optional defaults)
* `forwardPorts`: `[${templateOption:webtopPort}]`
* `portsAttributes`: label `Desktop (webtop)`
* `postCreateCommand`: `.devcontainer/postCreate.sh`

**.template/.devcontainer/compose.yaml**

```yaml
services:
  dev:
    image: ghcr.io/airnub-labs/dev-web:<tag>
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
      - "${WEBTOP_PORT:-3001}:3000"
    shm_size: "2gb"
```

**.template/.devcontainer/policies/managed.json** (example)

```json
{
  "BrowserSignin": 0,
  "PasswordManagerEnabled": false,
  "DefaultPopupsSetting": 2
}
```

---

## Images (optional, for speed)

* `images/dev-base`: Ubuntu 24.04 + Node 24 + pnpm + sane PNPM store.
* `images/dev-web`: FROM dev-base + Playwright deps + fonts + Chrome apt source.
* Publish multi-arch to GHCR; pin digests in templates for reproducibility.

---

## CI (GitHub Actions)

* `publish-features.yml`: publish `features/*` to GHCR as OCI artifacts (using `devcontainers/action`).
* `test-features.yml`: schema validate + minimal container boot + `install.sh` smoke test.
* `build-images.yml`: docker buildx multi-arch for `images/*`, push to GHCR.
* `test-templates.yml`: for each template → materialize into a temp dir → `devcontainer build` → smoke test ports (CDP/webtop) and tool versions.

---

## Migration tasks

1. **Discovery**: enumerate existing scripts that install Supabase/Codex/Claude/Gemini/Docker/CUDA/Chrome/noVNC/webtop.
2. **Extract → Features**: move installers into `features/<name>/install.sh` with corresponding `devcontainer-feature.json` and README notes. Ensure idempotency; non-root friendly.
3. **Sidecar browser**: remove GUI browser provisioning from primary container; implement only as sidecar in the `classroom-studio-webtop` template.
4. **Framework choice**: templates expose scaffold options (Next.js version, TS, App Router, auth). Keep tooling-only in Features.
5. **Docs**: write `SPEC-ALIGNMENT.md` and `CATALOG.md` mapping Features → Templates and usage examples.
6. **Versioning**: tag features/images/templates. Maintain `VERSIONING.md` and `docs/CATALOG.md` matrix.

---

## Acceptance criteria

* `devcontainer build` succeeds for every template locally and in CI.
* Features are consumed from the repository: `../../../../features/<id>` (still bump `version` in `devcontainer-feature.json`).
* `templates/nextjs-supabase` scaffolds when `scaffold=true` and runs with Supabase local (via CLI or compose), as documented.
* `classroom-studio-webtop` shows a working desktop via forwarded port; Chrome policies mount works and is easy to tweak.
* CI passes across publish + test workflows.

---

## Out-of-scope

* Heavily customizing the webtop upstream image beyond env/volumes/policies mount.
* Managing secrets inside features (use Codespaces Secrets / repo variables instead).

---

## Notes

* **Why sidecar for GUI browser?** Clean separation of concerns, smaller primary image, still fully spec-aligned via `dockerComposeFile` + `service` + `runServices`.
* **Why templates for frameworks?** Templates own project scaffolding and opinionated stacks; Features remain reusable tooling installers.

---

## Quick renaming suggestions

* `school-full` → `classroom-studio-webtop`
* `mcp-clis` → `agent-tooling-clis`
* Additional flavours: `classroom-studio-cdp`, `classroom-studio-nextjs-supabase`

---

## After completion

* Update `docs/CATALOG.md` with a matrix of templates × included features × versions.
* Add screenshots/gifs of Codespaces port forwarding (webtop desktop, CDP DevTools).
* Provide "one-click" badges/commands in each template README for Codespaces.

