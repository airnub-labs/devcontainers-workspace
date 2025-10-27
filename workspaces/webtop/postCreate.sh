#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Ensure PNPM store is writable (if node present)
mkdir -p /home/vscode/.pnpm-store && chown -R vscode:vscode /home/vscode/.pnpm-store || true

# Clone repos from blueprint (JSON parsed via node)
BP=workspaces/webtop/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/webtop/workspace.blueprint.json','utf8'));
  const repos = (bp.repos||[]);
  for (const r of repos) {
    const { url, path, ref } = r;
    if (!url || !path) continue;
    if (!fs.existsSync(path)) {
      console.log(`[clone] ${url} -> ${path}`);
      execSync(`git clone ${url} ${path}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${path} checkout ${ref}`, { stdio: 'inherit' });
    } else {
      console.log(`[skip] exists: ${path}`);
    }
  }
NODE
fi

# Print tool versions (non-fatal if missing)
node -v || true
pnpm -v || true
supabase --version || true
