# vscode-meta-workspace-internal

> Spec-aligned Dev Container **features**, **templates**, and **images** for Airnub Labs projects — with Supabase-first tooling and optional sidecar browsers.

This repository packages the tooling that powers our classrooms and product experiments. Every feature is OCI-ready, every template is spec-compliant, and CI keeps the published GHCR artifacts up to date. You can consume these building blocks directly in GitHub Codespaces, the `devcontainer` CLI, or any implementation of the [Dev Container specification](https://containers.dev/implementors/spec/).

---

## Highlights

- **Reusable tooling features** &mdash; Supabase CLI, headless Chrome CDP, Claude/Codex/Gemini CLIs, Docker-in-Docker ergonomics, and lightweight CUDA support live under [`features/`](./features).
- **Composable templates** &mdash; Ready-to-go `.devcontainer` payloads (web, Next.js + Supabase, classroom webtop) live under [`templates/`](./templates) with options to pick frameworks, scaffold projects, and toggle sidecars.
- **Prebuilt multi-arch images** &mdash; `images/dev-base` and `images/dev-web` build/push to `ghcr.io/airnub-labs` for fast Codespaces startups. Templates default to these images but can fall back to local Dockerfiles.
- **CI-backed distribution** &mdash; Workflows in [`.github/workflows/`](./.github/workflows) publish features (OCI), build & push images, and smoke-test each template via the Dev Containers CLI.
- **Docs for educators and maintainers** &mdash; See [`docs/`](./docs) for catalog tables, classroom rollout guides, security expectations, and migration steps from legacy shell scripts.

---

## Repository layout

```
features/    # Dev Container Features (Supabase CLI, Chrome CDP, agent CLIs, DinD+, CUDA-lite)
templates/   # Dev Container Templates (web, nextjs-supabase, classroom-studio-webtop)
images/      # Prebuilt base/web images published to GHCR
docs/        # Catalog, spec alignment, security, education setup, migration guides
.github/     # CI pipelines for publishing features, testing templates, and building images
.devcontainer/  # Dogfood workspace that consumes the local features during development
```

Each feature folder contains `devcontainer-feature.json`, an idempotent `install.sh`, and README notes. Each template ships `devcontainer-template.json`, a `.template/` payload with `.devcontainer/devcontainer.json`, and any companion scripts/Compose files.

---

## Quick start

### 1. Try a template locally

```bash
npm install -g @devcontainers/cli
mkdir my-app && cd my-app
devcontainer templates apply airnub-labs/web
# or: devcontainer templates apply airnub-labs/nextjs-supabase --option scaffold=true
```

The CLI materialises the `.devcontainer` folder with the selected options. Run `devcontainer up` or open the folder in VS Code and choose **Reopen in Container**.

### 2. Launch in GitHub Codespaces

Use the one-click badges in each template README or run:

```bash
gh codespace create --repo airnub-labs/vscode-meta-workspace-internal --branch main --devcontainer-path templates/web/.template/.devcontainer/devcontainer.json
```

Swap `templates/web` for `templates/nextjs-supabase` or `templates/classroom-studio-webtop` as needed.

### 3. Mix and match features

Reference the published features in any `devcontainer.json`:

```json
"features": {
  "ghcr.io/airnub-labs/devcontainer-features/supabase-cli:1": {
    "manageLocalStack": true,
    "projectRef": "my-project"
  },
  "ghcr.io/airnub-labs/devcontainer-features/chrome-cdp:1": {
    "channel": "beta",
    "port": 9333
  }
}
```

See the per-feature READMEs for option details.

---

## Template flavours

| Template | Use case | Included features | Notable options |
| --- | --- | --- | --- |
| [`templates/web`](./templates/web) | General web dev with Supabase CLI + headless Chrome | `chrome-cdp`, `supabase-cli` | `usePrebuiltImage`, `chromeChannel`, `cdpPort` |
| [`templates/nextjs-supabase`](./templates/nextjs-supabase) | Next.js apps with optional Supabase scaffolding | `chrome-cdp`, `supabase-cli`, `agent-tooling-clis` (toggle) | `scaffold`, `nextVersion`, `ts`, `appRouter`, `auth` |
| [`templates/classroom-studio-webtop`](./templates/classroom-studio-webtop) | Classroom/iPad flows with a webtop/noVNC sidecar | `supabase-cli`, `agent-tooling-clis` | `policyMode`, `webtopPort`, `chromePolicies` |

Each template exposes options via `devcontainer-template.json`. The `.template/.devcontainer/postCreate.sh` files handle idempotent setup such as pnpm installs or `create-next-app` scaffolding.

---

## Prebuilt images

- **`ghcr.io/airnub-labs/dev-base`** &mdash; Ubuntu 24.04, Node 24, pnpm with a tuned global store.
- **`ghcr.io/airnub-labs/dev-web`** &mdash; Extends `dev-base` with Chrome/Playwright dependencies and fonts.

Templates default to the latest `dev-web` tag. Set `usePrebuiltImage=false` to build locally with the provided Dockerfiles. Multi-arch manifests (amd64 + arm64) are produced by [`build-images.yml`](./.github/workflows/build-images.yml).

---

## Continuous integration

| Workflow | Purpose |
| --- | --- |
| [`publish-features.yml`](./.github/workflows/publish-features.yml) | Publishes every feature under `features/*` to GHCR as OCI artifacts. |
| [`test-features.yml`](./.github/workflows/test-features.yml) | Runs `devcontainer features test` against each feature for schema + smoke coverage. |
| [`build-images.yml`](./.github/workflows/build-images.yml) | Builds and pushes multi-arch `images/dev-base` and `images/dev-web`. |
| [`test-templates.yml`](./.github/workflows/test-templates.yml) | Applies each template, runs `devcontainer build`, then boots containers to verify ports/tools. |

Status badges and release notes will live alongside `VERSIONING.md` once the first tagged release ships.

---

## Migrating from legacy scripts

Legacy `.devcontainer/scripts` installers, GUI browser provisioning, and Supabase helpers now map to features and templates. Follow [`docs/MIGRATION.md`](./docs/MIGRATION.md) for step-by-step cleanup guidance, including how to:

1. Replace bespoke installers with feature references.
2. Adopt templates for downstream repos.
3. Move GUI workloads into the `classroom-studio-webtop` sidecar.
4. Re-point automation to the GHCR images/features.

---

## Additional documentation

- [`docs/CATALOG.md`](./docs/CATALOG.md) &mdash; Matrix of features and templates with option summaries.
- [`docs/SPEC-ALIGNMENT.md`](./docs/SPEC-ALIGNMENT.md) &mdash; How this repository maps to the Dev Container spec.
- [`docs/EDU-SETUP.md`](./docs/EDU-SETUP.md) &mdash; Rolling out classroom environments with Codespaces.
- [`docs/SECURITY.md`](./docs/SECURITY.md) &mdash; Secrets management, supply-chain notes, and extension policy.
- [`docs/MAINTAINERS.md`](./docs/MAINTAINERS.md) &mdash; Release process, version tagging, and CI troubleshooting.

---

## Dogfooding workspace

The `.devcontainer/` folder still provides the multi-repo meta workspace we use internally. It references the local features via `file:` URIs for fast iteration; production tags swap to `ghcr.io/airnub-labs/...` references during releases. Use it to verify changes before publishing new versions.

---

## Contributing

1. Add or modify features/templates/images locally.
2. Update documentation (`docs/` and `VERSIONING.md`) as needed.
3. Run `devcontainer features test` or `devcontainer templates apply` locally for smoke coverage.
4. Submit a PR; CI will publish artifacts once the changes merge to `main`.

Questions or suggestions? File an issue or ping the maintainers listed in [`docs/MAINTAINERS.md`](./docs/MAINTAINERS.md).
