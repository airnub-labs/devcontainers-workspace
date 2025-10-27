# Dev Container packaging roadmap (Legacy)

> **Note:** The active documentation now lives in [`SPEC-ALIGNMENT.md`](./SPEC-ALIGNMENT.md). This file is kept for historical context and will be removed in a future cleanup.

This document captures how the meta workspace evolves into a spec-compliant catalogue of Dev Container **features**, **templates**, and **stacks**. The goal is to keep the multi-repo developer workspace intact while letting downstream projects consume the same building blocks from GitHub Codespaces or any Dev Container implementation that follows the [Dev Container specification](https://containers.dev/implementors/spec/).

---

## Guiding principles

1. **Spec-first packaging.** Every reusable unit must ship the metadata files and folder structure defined in the spec so that tools such as `devcontainer` CLI, GitHub Codespaces, and VS Code can understand and publish them without translation layers.
2. **Composable layers.** Features configure single capabilities (DinD, GUI desktops, Supabase, auth helpers), templates combine features into repeatable environments, and stacks group templates for a specific curriculum or team scenario.
3. **Meta workspace parity.** The dogfooding workspace in `.devcontainer/` always consumes the published features/templates locally to guarantee parity between what we ship and what we use.
4. **Distribution-ready.** Automation builds, tests, version-tags, and publishes every artifact to the GitHub Container Registry (GHCR) in the format the spec calls for, so classrooms or partner repos can depend on immutable versions.

---

## Repository layout (spec-compliant)

```
devcontainers/
├── features/
│   └── <feature-id>/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── templates/
│   └── <template-id>/
│       ├── devcontainer.json
│       ├── template.json
│       ├── docker-compose.yml (optional)
│       └── README.md
└── stacks/
    └── <stack-id>/
        ├── stack.json
        └── README.md
```

* **Features** follow [spec §4](https://containers.dev/implementors/spec/#devcontainer-feature-json) and ship `devcontainer-feature.json` plus the install scripts. The metadata exposes options for Supabase ports, GUI toggles, Docker cache sizing, etc.
* **Templates** follow [spec §5](https://containers.dev/implementors/templates/) and package a `template.json` alongside the base `devcontainer.json`, Compose files, and assets. Each template references features via fully-qualified IDs (`ghcr.io/airnub-labs/devcontainers/<feature>@<version>`), ensuring downstream projects can reuse them directly.
* **Stacks** implement the experimental distribution format described in [spec §6](https://containers.dev/implementors/stacks/) to express curated combinations (for example, “classroom-gui + Supabase + Chrome DevTools”). Stacks reference published templates and include onboarding instructions.

The repository keeps `.devcontainer/` as the live workspace; its `devcontainer.json` imports the local features with the `file:` URI during development and switches to registry references in published tags.

---

## Feature catalogue alignment

| Feature | Purpose | Spec considerations |
| --- | --- | --- |
| `docker-dind` | Wraps DinD provisioning and workspace permissions. | `mounts` and `init` scripts adhere to the spec’s lifecycle hooks (`onCreateCommand`, `customizations`). |
| `supabase-stack` | Boots the shared Supabase services with deterministic Compose project names. | Publishes configuration options for ports, project refs, and bind-mount roots via the `options` block. |
| `gui-desktop` | Provides web-accessible desktops (noVNC/Webtop/Chrome) for tablet/phone workflows. | Exposes optional profiles, port forwarding, and password settings as user-configurable options. |
| `codespaces-repo-cloner` | Reproduces the current clone automation as a reusable feature. | Uses the `init` stage to add helper scripts and extends `devcontainer.json` via `customizations`. |

Each feature README documents inputs, defaults, and compatibility notes (host requirements, known Codespaces limits). The install scripts are idempotent and avoid host-specific assumptions so they pass the spec’s validation tooling.

---

## Template tiers

1. **`base` template** – installs the shared CLI toolchain (Node 24 + pnpm, Python 3.12, Supabase CLI, `airnub` helpers) and configures workspace mounts. Acts as the foundation for all other templates.
2. **`full-gui` template** – inherits `base` and adds the `gui-desktop` feature plus Codespaces `forwardPorts` entries and VS Code `customizations` for Chrome debugging.
3. **`api-only` template** – inherits `base` but omits GUI features; ideal for backend/CLI-first projects where Supabase and DinD remain available.
4. **`classroom-starter` template** – extends `full-gui` and sets opinionated defaults for classroom use (pre-cloned sample repos, pinned extension set, deterministic user passwords for support staff).

Templates carry README files with quick-start instructions, Codespaces compatibility notes, and sample `devcontainer.json` snippets to consume them in downstream repos.

---

## Stacks for curricula and teams

Stacks publish curated bundles so educators or teams can pick a single reference without hand-picking features. Examples:

| Stack ID | Composition | Primary use |
| --- | --- | --- |
| `supabase-web` | `templates/full-gui` + Supabase feature pre-configured for analytics/storage. | Full-stack web courses needing GUI + database. |
| `backend-lite` | `templates/api-only` + Redis service bindings. | Terminal-first backend lessons with minimal GUI overhead. |
| `product-lab` | `templates/full-gui` + additional features (Playwright, Chrome DevTools). | Cross-device product experimentation with live browser debugging. |

Each `stack.json` references the template URIs, declares recommended extensions, and links to docs describing classroom rollout steps.

---

## Distribution and automation

1. **Validation** – GitHub Actions runs `devcontainer features test` and `devcontainer templates test` against every artifact. Smoke tests cover Supabase boot, GUI reachability, and Codespaces-specific behaviours (port forwarding, persistent volumes).
2. **Versioning** – Tags in the form `features/<feature-id>/vX.Y.Z` and `templates/<template-id>/vX.Y.Z` trigger publishing jobs. Versions map directly to GHCR tags (`ghcr.io/airnub-labs/devcontainers/<feature-id>:vX.Y.Z`).
3. **Documentation** – Workflow outputs update `docs/feature-catalog.md` and `docs/template-matrix.md` with the latest published versions. README badges show the current release for visibility.
4. **Consumption** – Downstream repos reference the registry images directly in their `devcontainer.json`. The meta workspace references the same versions to guarantee parity between development and published artifacts.

---

## Meta workspace consumption pattern

* During development (`main` branch), `.devcontainer/devcontainer.json` points to local features using `"features": { "file:../devcontainers/features/<id>": {} }` to speed up iteration.
* During release, a script rewrites those entries to the registry-qualified IDs before tagging. The devcontainer CLI’s [lock file support](https://containers.dev/implementors/cli/#lock-files) captures resolved versions so Codespaces and local builds stay deterministic.
* The workspace retains Docker Compose orchestration for shared services, but Compose files used by templates live under `devcontainers/templates/<id>/` and are symlinked or copied during packaging to honour the spec’s relative path rules.

This approach keeps the flagship multi-repo workspace operational while ensuring every reusable component complies with the Dev Container specification and can be distributed like official features/templates.
