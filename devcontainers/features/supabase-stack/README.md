# Supabase stack feature

## Purpose
Bootstraps the Supabase local development stack inside the inner Docker daemon. It mirrors the repo’s Supabase configuration, ensures persistent volume directories exist, starts the Compose project with deterministic naming, and synchronises Supabase environment variables back into the workspace log.

## Inputs & options
The feature does not define custom options, but it forwards the following environment variables from the host to influence Supabase start-up:

- `SUPABASE_INCLUDE` – services to include when starting Supabase (default aligns with Supabase CLI defaults).
- `SUPABASE_PROJECT_DIR` / `SUPABASE_CONFIG_PATH` – location of the Supabase project root and config file.
- `SUPABASE_START_ARGS` – extra arguments passed verbatim to `supabase start`.
- `SUPABASE_START_EXCLUDES` – space-separated service names to convert into repeated `-x` flags.

Additional Docker timing knobs (`SUPABASE_DOCKER_WAIT_ATTEMPTS`, `SUPABASE_DOCKER_WAIT_SLEEP_SECS`, `DOCKER_WAIT_*`) are honoured when present.

## Lifecycle hooks
`postStartCommand` runs [`bin/bootstrap-supabase.sh`](./scripts/bootstrap-supabase.sh). The script waits for Docker, validates Supabase CLI availability, ensures the Supabase project directory exists, and launches `supabase start` with the computed include/exclude arguments under a predictable Compose project name. It also runs the repo’s `scripts/db-env-local.sh --status-only` helper to synchronise environment variables when available. The feature additionally ships [`bin/supabase-up.sh`](./scripts/supabase-up.sh) for task runners to start Supabase manually with the same include/exclude logic.

## Compatibility
Requires the Supabase CLI and the upstream `docker-in-docker` feature to provide an inner Docker daemon. When Supabase configuration files are missing, Docker is unavailable, or the CLI is not installed, the bootstrap script logs the condition and exits successfully so Codespaces and local dev containers continue to start.
