#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BP=workspaces/novnc/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/novnc/workspace.blueprint.json','utf8'));
  const repos = (bp.repos||[]);
  for (const r of repos) {
    const { url, path, ref } = r;
    if (!url || !path) continue;
    if (!fs.existsSync(path)) {
      console.log(`[clone] ${url} -> ${path}`);
      execSync(`git clone ${url} ${path}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${path} checkout ${ref}`, { stdio: 'inherit' });
    }
  }
NODE
fi
