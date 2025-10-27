# Chrome DevTools Protocol Feature

Installs Google Chrome (or Chromium on non-amd64 architectures) and launches a headless DevTools Protocol endpoint via `supervisord`.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `channel` | enum(`stable`,`beta`) | `"stable"` | Chrome channel to install. |
| `port` | integer | `9222` | Port exposed by the headless Chrome instance. |

The feature writes a `/etc/profile.d/chrome-cdp.sh` script that exports `CDP_PORT` and lazily starts `supervisord` on login if the service is not already running. Use template `forwardPorts` to expose the CDP endpoint to the host.
