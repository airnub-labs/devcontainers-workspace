# GUI Providers

The workspace ships two GUI desktop variants that run alongside the main development container. Pick the variant that best fits your workflow and VS Code (or Codespaces) will launch the matching sidecar services automatically.

## Variants

| Variant | Location | Description |
| --- | --- | --- |
| Webtop (default) | [`workspaces/webtop/.devcontainer`](../workspaces/webtop/.devcontainer) | Uses [linuxserver/webtop](https://docs.linuxserver.io/images/docker-webtop/) to expose a full XFCE desktop over HTTPS at port 3001 with Chrome pre-wired for remote debugging on 9222. |
| noVNC | [`workspaces/novnc/.devcontainer`](../workspaces/novnc/.devcontainer) | Uses [`dorowu/ubuntu-desktop-lxde-vnc`](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc) to expose an LXDE session via VNC-over-WebSocket on port 6080. |

The root `.devcontainer/devcontainer.json` points at the Webtop variant so Codespaces works out of the box. To launch noVNC instead, pick `.devcontainer/novnc/devcontainer.json` from the Dev Containers / Codespaces profile picker.

## Ports & debugging

| Service | Port | Notes |
| --- | --- | --- |
| Chrome DevTools (CDP) | 9222 | Shared across variants via the `chrome-cdp` feature. Visit `http://localhost:9222/json/version`. |
| Webtop desktop | 3001 | HTTPS desktop with audio via WebRTC. |
| noVNC desktop | 6080 | HTTP endpoint that proxies VNC frames. |

All GUI ports are marked **Private** in the devcontainer configuration. Share URLs only with trusted collaborators.

## Audio & helper scripts

Legacy helpers such as `start-desktop.sh`, `novnc-audio-bridge.sh`, and `supabase-up.sh` now live in `workspaces/<variant>/`. They are optional entry points you can call from `postStart.sh` if you need to extend the default behaviour (for example enabling audio forwarding or custom Chrome policies).

The Supabase include/exclude helper also lives alongside the variant configuration (`workspaces/webtop/supabase-up.sh`). It translates high-level service lists into the flags consumed by the Supabase CLI.
