# Post-create Script Review

This document summarizes the activity recorded in the most recent `postCreateCommand` log and captures the follow-up actions that were addressed afterwards.

## Summary
- pnpm store configured at `/home/vscode/.pnpm-store`; package installation skipped because no `package.json` was present.
- Supabase CLI installed at version `2.53.6`.
- Deno, Codex, Gemini, Claude, and airnub CLIs installed and added to the PATH.
- System package indices refreshed; window-management utilities (`wmctrl`, `libxdo3`, `xdotool`) installed alongside `x11-utils` for `xrandr`/`xdpyinfo` diagnostics.
- Google Chrome is now ensured during post-create (falling back to `google-chrome-stable` when no Chromium-based browser is present).
- Workspace repositories cloned into `/airnub-labs`, including `airnub-labs/million-dollar-maps` (ignored by the meta-workspace Git).
- A managed Chrome/Chromium classroom policy is written to `/etc/opt/chrome/policies/managed/classroom.json` (and mirrored to `/etc/chromium/policies/managed/` when Chromium exists) to allow only loopback hosts plus the GitHub/vscode.dev domains used by Codespaces (including `github.dev`, `vscode.dev`, `*.github.dev`, `*.app.github.dev`, and `*.githubpreview.dev`) while blocking all extensions and leaving DevTools enabled.
- The post-start script now ships a noVNC landing page that auto-connects, auto-reconnects, requests remote resize, and exposes an audio bridge when available.
- Supabase start-up now authenticates to Amazon ECR Public when AWS credentials are present, ensuring image pulls are less likely to rate-limit.
- Audio bridge prerequisites (`pulseaudio`, `ffmpeg`) are installed on-demand.

## Next Steps

1. **Verify Chrome availability and policies**
   - Run `command -v google-chrome || command -v chromium` to confirm the browser binary is present.
   - Launch the remote desktop preview (port 6080) and browse to `chrome://policy` to confirm the managed policy is applied.

2. **Confirm remote desktop auto-connect behaviour**
   - Open the VS Code / Codespaces port preview for `6080`; it should immediately redirect to `vnc.html` with `autoconnect`, `reconnect`, and `resize=remote` parameters.
   - Use `DISPLAY=${DISPLAY:-:1} xrandr` inside the container to confirm `x11-utils` support is active when diagnosing resize issues.

3. **Desktop/post-start health check**
   - Optional: paste the following commands into a terminal after attach to verify the chain is healthy:

     ```bash
     ss -ltnp | egrep '6080|590|5432[1-4]' || true
     pgrep -a Xvfb; pgrep -a x11vnc; pgrep -a websockify; pgrep -a fluxbox || true
     curl -sSf http://localhost:6080/ | head -n2
     command -v google-chrome || command -v chromium || echo "no Chrome/Chromium found"
     DISPLAY=${DISPLAY:-:1} xrandr 2>/dev/null || echo "xrandr not available (install x11-utils)"
     ```

No additional action is required unless one of the verification steps surfaces an issue.
