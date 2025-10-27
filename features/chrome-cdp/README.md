# Chrome DevTools Protocol Feature

Installs Google Chrome (or Chromium on non-amd64 architectures) and launches a headless DevTools Protocol endpoint via `supervisord`.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `channel` | enum(`stable`,`beta`) | `"stable"` | Chrome channel to install. |
| `port` | integer | `9222` | Port exposed by the headless Chrome instance. |

The feature writes a `/etc/profile.d/chrome-cdp.sh` script that exports `CDP_PORT` (also surfaced via `containerEnv`) and lazily starts `supervisord` on login if the service is not already running. `start-supervisord.sh` waits for Chrome's `/json/version` endpoint on `CDP_PORT` before exiting (up to 45 seconds by default, configurable through `CDP_READY_TIMEOUT` and `CDP_READY_INTERVAL`). The readiness probe monitors the supervisor process between retries so concurrent logins reuse the same wait loop, which keeps the Dev Containers CI smoke test green.

Use template `forwardPorts` to expose the CDP endpoint to the host.
