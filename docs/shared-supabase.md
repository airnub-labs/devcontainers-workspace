# Shared Supabase operations

The Dev Container and Codespaces sessions share a single Supabase stack configured in [`supabase/config.toml`](../supabase/config.toml). Every project in `/workspaces` should target that stack instead of starting its own instance.
This document explains how the meta workspace provides a single, shared Supabase stack (and a Redis sidecar) for every project mounted under `/workspaces`.

Why a shared stack?

* Run one Supabase + Redis instance instead of many. This reduces CPU/memory usage, avoids port collisions, and speeds up switching between projects.
* Centralized credentials and env-syncing mean you can apply migrations from any project without reconfiguring hosts or ports.
* Works equally well locally and in GitHub Codespaces because the Dev Container exposes the same shared ports and env files.

---

## Ports and services

The Supabase CLI spins up multiple services when you run `supabase start`. The meta workspace exposes these on fixed ports so every project can connect to the same endpoints:

| Service | Port | Notes |
| ------- | ---- | ----- |
| API | `54321` | REST/Realtime API used by apps. |
| Postgres | `54322` | Database access used by the CLI during migrations. |
| Studio | `54323` | Web UI for inspecting data: [http://localhost:54323](http://localhost:54323). |
| Inbucket | `54324` | Email testing inbox. |
| Storage | `54326` | Object storage API. |
| Analytics (Logflare) | `54327` | Supabase analytics/logging endpoint. |

A Redis sidecar is available at `6379` (defined in `.devcontainer/docker-compose.yml`). Because these ports are fixed and shared, you avoid the complexity of tracking different ports for each project.

---

## Starting and stopping the stack

### Start/stop (quick)

Run these commands inside the Dev Container (or Codespace) terminal:

```bash
supabase start   # launch all services and write fresh credentials to supabase/.env.local
supabase stop    # stop the stack when you are finished
```

The first command also generates/updates `supabase/.env.local` with environment variables for the shared project. Helper scripts use that file to sync credentials into each project.

If you restart the container, re-run `supabase start` once per session so services and env vars are current.

---

## Running migrations from a project

1. `cd /workspaces/<project>`.
2. Use the Supabase CLI with the shared project ref:

   ```bash
   supabase db push --project-ref airnub-labs --local
   ```

   *Replace `push` with `reset` to perform a destructive reset:*

   ```bash
   supabase db reset --project-ref airnub-labs --local -y
   ```

Why the extra flag? The CLI normally infers a project ref based on the current directory name. Without `--project-ref airnub-labs` (or `SUPABASE_PROJECT_REF=airnub-labs`), it looks for containers named after the repo and fails. The shared ref is declared once in `supabase/config.toml` and reused across projects.

---

## Helper scripts

Two scripts in `supabase/scripts/` streamline Supabase operations:

### `db-env-local.sh`

* Captures the output of `supabase status -o env` (or `supabase start -o env` as a fallback) into `supabase/.env.local`.
* Accepts `--status-only` to skip starting the stack, `--ensure-start` to allow starting it, and `--project-dir` to target a different Supabase config directory.
* Used internally by other scripts to keep credentials fresh.

### `use-shared-supabase.sh`

Copy or symlink this script into each project (for example `scripts/use-shared-supabase.sh`). It wraps the Supabase CLI and keeps `.env.local` files aligned.

Available subcommands:

```bash
./scripts/use-shared-supabase.sh push    # supabase db push --project-ref airnub-labs --local
./scripts/use-shared-supabase.sh reset   # supabase db reset --project-ref airnub-labs --local -y
./scripts/use-shared-supabase.sh status  # supabase status -o env --project-ref airnub-labs
```

What it does on every run:

1. Reads the shared `project_id` from `supabase/config.toml` (or `SUPABASE_PROJECT_REF` if already set).
2. Calls `db-env-local.sh` to ensure `supabase/.env.local` exists and contains up-to-date credentials.
3. Copies those credentials into the project’s `.env.local` while preserving any project-specific variables and pruning deprecated Supabase keys (`SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).

You can override the target env file by exporting `PROJECT_ENV_FILE` before invoking the script.

## Troubleshooting & performance tips

If you run into problems when using the shared stack, these quick checks solve most issues:

* Port collisions: ensure you don't have another local Supabase instance running (search for `supabase` containers with `docker ps`). Stop them or run `supabase stop` in the meta workspace.
* Stale credentials: re-run `./supabase/scripts/db-env-local.sh --ensure-start` in the Dev Container to refresh `supabase/.env.local` and then run `./scripts/use-shared-supabase.sh status` from your project to sync.
* App server collisions: stop any local app processes (for example, a leftover `npm run dev`) before switching projects to avoid reusing forwarded ports like `3000`.
* High memory/CPU: if your machine struggles, allocate more resources to Docker or run fewer heavy services simultaneously (e.g., stop analytics sidecar if not needed).
* Logs: `supabase logs` (in the container) and `docker compose logs supabase` are helpful for diagnosing service failures.

If you need an isolated Supabase instance for a single repo (rare), use that project's `.devcontainer` and a local Supabase run — but prefer the shared stack for day-to-day cross-repo development.

---

## Best practices

* **One stack for all repos.** Apply a project’s migrations, then switch directories and apply the next project’s migrations when needed.
* **Check status if something feels off.** `./scripts/use-shared-supabase.sh status` confirms whether the services are up and refreshes env vars without starting the stack.
* **Stop stale servers.** Shut down any running app processes from the previous project before switching to avoid port collisions.
* **Commit env scaffolding, not secrets.** If you decide to track the shared `supabase/.env.local`, use it only for bootstrap values. The helper script preserves any additional project-specific secrets stored in each project’s `.env.local`.
