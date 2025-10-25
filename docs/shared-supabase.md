# Shared Supabase operations

The Dev Container and Codespaces sessions share a single Supabase stack configured in [`supabase/config.toml`](../supabase/config.toml). Every project in `/workspaces` should target that stack instead of starting its own instance.
This document explains how the meta workspace provides a single, shared Supabase stack (and a Redis sidecar) for every project mounted under `/workspaces`.

Why a shared stack?

* Run one Supabase + Redis instance instead of many. This reduces CPU/memory usage, avoids port collisions, and speeds up switching between projects.
* Centralized credentials and env-syncing mean you can apply migrations from any project without reconfiguring hosts or ports.
* Works equally well locally and in GitHub Codespaces because the Dev Container exposes the same shared ports and env files.

---

## Ports and services

The Supabase CLI spins up multiple services when you run `supabase start -o env`. The meta workspace exposes these on fixed ports so every project can connect to the same endpoints:

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
supabase start -o env   # launch all services and write fresh credentials to supabase/.env.local
supabase stop           # stop the stack when you are finished
```

The first command also generates/updates `supabase/.env.local` with environment variables for the shared project. Helper scripts use that file to sync credentials into each project.

If you restart the container, re-run `supabase start -o env` once per session so services and env vars are current.

---

## Running migrations from a project

### One-command workflow with the `airnub` CLI

From the workspace root, use the bundled CLI to sync credentials, apply migrations to the shared stack, or inspect its status without remembering Supabase flags:

```bash
./airnub use ./million-dollar-maps                        # env sync + migrations + status in one step
./airnub project current                                  # show which project was activated last
./airnub db reset --project-dir ./million-dollar-maps      # destructive reset (non-interactive)
./airnub db status --project-dir ./million-dollar-maps     # check shared stack status
```

All subcommands accept relative or absolute paths, forward extra arguments after `--` to the Supabase CLI, and surface the same behaviour as the helper scripts described later in this guide.

`airnub use` is the beginner-friendly path: it resolves the project directory, syncs `.env.local`, runs `supabase db push`, then prints `supabase status` so you can immediately confirm which project is wired to the shared stack. The command also records the selection in `supabase/.airnub-current-project`, which powers `airnub project current` for quick checks when you return to the workspace later. Add `--skip-status` if you prefer to omit the status call.

### Manual Supabase CLI workflow

1. `cd /workspaces/airnub-labs` (the workspace root).
2. Run the Supabase CLI and point it at the project directory with `--workdir`:

   ```bash
   supabase db push --workdir ./<project-name> --local
   ```

   For example, to push migrations for `million-dollar-maps`:

   ```bash
   supabase db push --workdir ./million-dollar-maps --local
   ```

   *Replace `push` with `reset` to perform a destructive reset:*

   ```bash
   supabase db reset --workdir ./million-dollar-maps --local -y
   ```

Why `--workdir`? The Supabase CLI infers its configuration from the working directory. By running the command from the shared workspace root and specifying each project’s folder, the CLI uses that project’s migrations while still targeting the shared stack defined in `supabase/config.toml`.

---

## Helper scripts

The executable [`./airnub`](../airnub) lives at the repository root and wraps two scripts in `supabase/scripts/` that streamline Supabase operations. You can call those scripts directly when you need lower-level access or want to integrate them into other automation.

### `db-env-local.sh`

* Captures the output of `supabase status -o env` (or `supabase start -o env` as a fallback) into `supabase/.env.local`.
* Accepts `--status-only` to skip starting the stack, `--ensure-start` to allow starting it, and `--project-dir` to target a different Supabase config directory.
* Used internally by other scripts to keep credentials fresh.

### `use-shared-supabase.sh`

Copy or symlink this script into each project (for example `scripts/use-shared-supabase.sh`). It wraps the Supabase CLI and keeps `.env.local` files aligned.

Available subcommands:

```bash
./scripts/use-shared-supabase.sh push    # supabase db push --workdir "$(pwd)" --local
./scripts/use-shared-supabase.sh reset   # supabase db reset --workdir "$(pwd)" --local -y
./scripts/use-shared-supabase.sh status  # supabase status -o env --workdir "$(pwd)"
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
