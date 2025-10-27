# GUI Providers

The workspace can launch one or more browser-based desktops alongside the main
`devcontainer`. Use the configuration values in `.devcontainer/.env.example`
(and your own `.env`) to decide which desktop sidecars run and how they expose
remote debugging or audio features.

## Selecting providers

Set `GUI_PROVIDERS` to a comma-separated list containing any of the following
providers:

- `novnc` – the existing Chrome + noVNC desktop
- `webtop` – [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/)
- `chrome` – [LinuxServer Chrome](https://docs.linuxserver.io/images/docker-chrome/)

You can also use the shortcut `GUI_PROVIDERS=all` to launch every desktop at the
same time. The `.devcontainer/scripts/select-gui-profiles.sh` helper translates
this list into Docker Compose profiles so that Codespaces or local devcontainers
start exactly the sidecars you need.

## Default ports and authentication

| Provider | HTTPS / HTTP | DevTools (CDP) | Notes |
| --- | --- | --- | --- |
| noVNC | `${GUI_NOVNC_HTTP_PORT:-6080}` | `${GUI_NOVNC_DEVTOOLS_PORT:-9222}` | Audio bridge available on 6081 (Opus/OGG) |
| Webtop | `${GUI_WEBTOP_HTTPS_PORT:-3001}` | `${GUI_WEBTOP_DEVTOOLS_PORT:-9223}` | Requires HTTPS for audio/video; credentials from `WEBTOP_USER` / `WEBTOP_PASSWORD` |
| Chrome | `${GUI_CHROME_HTTPS_PORT:-3002}` | `${GUI_CHROME_DEVTOOLS_PORT:-9224}` | Credentials reuse `CHROME_USER` / `CHROME_PASSWORD` |

> **Codespaces URLs**
>
> - noVNC: `https://<workspace>-6080.<region>.codespaces-preview.app`
> - Webtop: `https://<workspace>-3001.<region>.codespaces-preview.app`
> - Chrome: `https://<workspace>-3002.<region>.codespaces-preview.app`
> - DevTools: visit `http(s)://…:<port>/json` for each provider

All GUI ports are marked as **Private** in `devcontainer.json`. Keep the
forwarded URLs private (especially when using the basic-auth credentials from
`.env`).

## Audio and remote debugging

- **Webtop audio** – Controlled via `WEBTOP_AUDIO` (default `1`). Webtop ships
  with WebRTC/WebCodecs audio streaming that works when the forwarded port is
  served over HTTPS (true for Codespaces).
- **Chrome DevTools** – `GUI_CHROME_DEBUG` toggles the remote debugging ports for
  both Webtop and Chrome. When enabled, helper scripts inside each container
  start Chromium/Chrome with `--remote-debugging-port`. Set the variable to `0`
  to disable the listeners (`/json` endpoints will stop responding).

## Running providers concurrently

Each sidecar container is assigned its own Compose profile:

- `gui-novnc`
- `gui-webtop`
- `gui-chrome`

When you run `GUI_PROVIDERS=all`, the sidecars bind to distinct host ports so
that they can run simultaneously without conflicts. Use a subset—such as
`GUI_PROVIDERS=webtop,chrome`—to limit which profiles start on the next
`devcontainer up`.

## Supabase include list helper

The `SUPABASE_INCLUDE` variable lists the Supabase services you want to run
(e.g. `db,auth,rest`). The `.devcontainer/scripts/supabase-up.sh` task translates
that into the exclusion list expected by `supabase start -x ...`, so you can
control the Supabase stack purely via environment variables.
