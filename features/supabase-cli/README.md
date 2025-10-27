# Supabase CLI Feature

Installs the [Supabase CLI](https://supabase.com/docs/guides/cli) inside a dev container. Supports pinning to a specific release, exporting a `SUPABASE_PROJECT_REF`, and optionally shipping helper wrappers for local stack commands.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `"latest"` | Semver or tag for the Supabase CLI. |
| `manageLocalStack` | boolean | `false` | Adds `sbx-start`, `sbx-stop`, and `sbx-status` helpers that wrap `supabase` local stack commands. |
| `services` | string[] | _optional_ | Advisory list of Supabase services (captured in install metadata). |
| `projectRef` | string | _optional_ | Populates `SUPABASE_PROJECT_REF` via `/etc/profile.d` and `containerEnv`. |

Helper scripts are only created when `manageLocalStack` is enabled. The feature is idempotent and will skip reinstalling the CLI when the requested version is already present.
