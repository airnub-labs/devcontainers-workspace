#!/usr/bin/env bash
set -euo pipefail

# Apply a managed Chrome/Chromium classroom policy so the bundled browser
# cooperates with GitHub-hosted tooling (github.dev, vscode.dev, Codespaces
# previews) while keeping the remote desktop locked down to known origins.

log() {
  echo "[chrome-policy] $*"
}

declare -a POLICY_TARGETS=("/etc/opt/chrome/policies/managed")
if [[ -d "/etc/chromium/policies" ]]; then
  POLICY_TARGETS+=("/etc/chromium/policies/managed")
fi

if [[ ${#POLICY_TARGETS[@]} -eq 0 ]]; then
  log "No Chrome/Chromium policy directories detected; skipping managed policy."
  exit 0
fi

log "Writing managed Chrome policy for targets: ${POLICY_TARGETS[*]}"

python3 - "${POLICY_TARGETS[@]}" <<'PY'
import json
import os
import pathlib
import sys

allowlist = [
    "chrome://*",
    "devtools://*",
    "http://localhost/*",
    "https://localhost/*",
    "http://127.0.0.1/*",
    "https://127.0.0.1/*",
    "http://[::1]/*",
    "https://[::1]/*",
    "http://0.0.0.0/*",
    "https://0.0.0.0/*",
    "https://github.com/*",
    "https://*.github.com/*",
    "https://github.dev/*",
    "https://*.github.dev/*",
    "https://vscode.dev/*",
    "https://*.vscode.dev/*",
    "https://*.app.github.dev/*",
    "https://*.githubpreview.dev/*",
    "https://*.githubusercontent.com/*",
    "https://*.githubassets.com/*",
    "https://avatars.githubusercontent.com/*",
    "https://*.vsassets.io/*",
    "https://*.visualstudio.com/*",
    "https://*.vscode-unpkg.net/*",
]

extra_allowlist = [item for item in os.environ.get("CHROME_POLICY_EXTRA_ALLOWLIST", "").split() if item]
allowlist.extend(extra_allowlist)

deduped_allowlist = sorted(dict.fromkeys(allowlist))

policy = {
    "URLBlocklist": ["*"],
    "URLAllowlist": deduped_allowlist,
    "ExtensionInstallBlocklist": ["*"],
    "ExtensionInstallAllowlist": [],
    "ExtensionInstallForcelist": [],
    "ExtensionAllowedTypes": ["theme"],
    "DeveloperToolsAvailability": 1,
    "AutoplayAllowlist": deduped_allowlist,
}

for directory in sys.argv[1:]:
    path = pathlib.Path(directory) / "classroom.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(policy, indent=2) + "\n", encoding="utf-8")
PY

log "Managed Chrome policy applied."
