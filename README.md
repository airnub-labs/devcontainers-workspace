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

### Option A — Local VS Code + Dev Containers

1. Open `airnub-labs.code-workspace` in VS Code and choose **Reopen in Container**.
2. In the Dev Container terminal, list the mounted repos with `ls /workspaces`.
3. Start the shared services once per session: `supabase start` (Studio: http://localhost:54323, API: http://localhost:54321). This single stack serves all projects in `/workspaces` so you don't need a separate Supabase instance per repo.
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

Full instructions for automation, env sync, and helper usage live in the documentation below. See the "Troubleshooting & performance" section in `docs/shared-supabase.md` if you hit port collisions, heavy resource usage, or stale credentials.

---

## Learn more

* **[Workspace architecture](./docs/workspace-architecture.md):** how the Dev Container is wired, what services run, and how the multi-root workspace is organized.
* **[Shared Supabase operations](./docs/shared-supabase.md):** start/stop commands, helper script usage, and env-var management.
* **[Workspace clone strategy](./docs/clone-strategy.md):** how repo permissions translate into automatic cloning in Dev Containers and Codespaces.

---

**TL;DR:** Open the workspace, run `supabase start`, and develop any Airnub Labs project against the shared stack without juggling multiple containers.
