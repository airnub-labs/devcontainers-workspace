# vscode-meta-workspace-internal

> One dev container, many projects — with a shared Redis and **one** local Supabase stack. Works locally and in **GitHub Codespaces**.

This repo gives you a ready-to-go workspace for Airnub Labs projects. Open a single VS Code window and the Dev Container boots a workspace that mounts sibling repos and exposes a single, shared Supabase + Redis runtime.

Why a shared stack? Running one Supabase and Redis instance avoids the common local developer problems of "too many ports", duplicate local databases, and the CPU/memory cost of multiple full stacks. It makes switching between projects fast, reduces container churn, and keeps local resource usage predictable.

---

## What you get

* **Multi-root workspace:** `airnub-labs.code-workspace` opens all of your project folders side-by-side.
* **Shared runtime:** the Dev Container maps the parent directory to `/workspaces`, provides Docker-in-Docker, Node 24 with pnpm, Python 3.12, and ships with Redis plus a Supabase local stack configured in [`supabase/config.toml`](./supabase/config.toml).
* **Helper scripts:** `.devcontainer/scripts/` manages cloning and bootstrap tasks, while `supabase/scripts/` keeps local Supabase credentials in sync across repos.

---

## Quick start

### Using this workspace in your own GitHub org

If another team wants to adopt this setup, offer them two paths:

* **Create a new repo from this template** – keeps their copy private and lets them customize without affecting the original. In GitHub, choose **Use this template → Create a new repository** and select their organization/visibility.
* **Fork this repo** – keeps an upstream link for easy updates, but the fork will be public to match this repository’s visibility. Only suggest this if public visibility is acceptable.

The first build of the Dev Container or Codespace needs a few minutes while the image is assembled. After that initial build, starting/stopping the container (locally or in Codespaces) is fast, and the environment behaves the same in both places.

### Option A — Local VS Code + Dev Containers

1. Open `airnub-labs.code-workspace` in VS Code and choose **Reopen in Container**.
2. In the Dev Container terminal, list the mounted repos with `ls /workspaces`.
3. Start the shared services once per session: `supabase start` (Studio: [http://localhost:54323](http://localhost:54323), API: [http://localhost:54321](http://localhost:54321)). This single stack serves all projects in `/workspaces` so you don't need a separate Supabase instance per repo.
4. Work in a project folder (for example `cd /workspaces/million-dollar-maps`) and run that project’s migrations against the shared stack.

### Option B — GitHub Codespaces

1. Create a Codespace from this repo.
2. (Optional) Update `.devcontainer/devcontainer.json → customizations.codespaces.repositories` so the Codespace token can clone other private repos.
3. After the container boots, clone sibling repos into `/workspaces/<repo>` (post-create hooks handle the common cases) and use the same Supabase workflow as local.

Need a refresher on the helper scripts or the clone automation? See the docs linked below.

---

## Shared Supabase workflow (at a glance)

* Services run with the project ref defined in [`supabase/config.toml`](./supabase/config.toml) — by default `airnub-labs`.
* Run migrations with the Supabase CLI from inside the project directory, always targeting the shared ref:

```bash
supabase db push --project-ref airnub-labs --local
```

* Copy `supabase/scripts/use-shared-supabase.sh` into your project (or call it directly) to sync env vars, apply migrations, reset, or check status with a single command.

---

## Learn more

* **[Workspace architecture](./docs/workspace-architecture.md):** how the Dev Container is wired, what services run, and how the multi-root workspace is organized.
* **[Shared Supabase operations](./docs/shared-supabase.md):** start/stop commands, helper script usage, and env-var management.
* **[Workspace clone strategy](./docs/clone-strategy.md):** how repo permissions translate into automatic cloning in Dev Containers and Codespaces.

---

**TL;DR:** Open the workspace, run `supabase start`, and develop any Airnub Labs project against the shared stack without juggling multiple containers.
