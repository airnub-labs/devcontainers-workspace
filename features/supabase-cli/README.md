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

### Service name hints

The `services` option does not toggle Supabase components directly; instead it records your intent so templates can translate the list into `supabase start` flags or Compose overrides. Use the canonical Supabase service identifiers shown below:

| Service hint | CLI flag (`supabase start`) | Compose service |
| --- | --- | --- |
| `db` | `--exclude db` when omitted | `supabase-db` |
| `auth` | `--exclude auth` when omitted | `supabase-auth` |
| `rest` | `--exclude rest` when omitted | `supabase-rest` |
| `realtime` | `--exclude realtime` when omitted | `supabase-realtime` |
| `storage` | `--exclude storage` when omitted | `supabase-storage` |
| `studio` | `--exclude studio` when omitted | `supabase-studio` |
| `imgproxy` | `--exclude imgproxy` when omitted | `supabase-imgproxy` |
| `vector` | `--exclude vector` when omitted | `supabase-vector` |
| `pgbouncer` | `--exclude pgbouncer` when omitted | `supabase-pgbouncer` |
| `logflare` | `--exclude logflare` when omitted | `supabase-logflare` |
| `inbucket` | `--exclude inbucket` when omitted | `supabase-inbucket` |

Templates may use the recorded list to pre-populate `sbx-start` arguments, hydrate `.devcontainer/compose` overrides, or simply document which services a project relies on.
