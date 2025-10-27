#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

mkdir -p /home/vscode/.pnpm-store && chown -R vscode:vscode /home/vscode/.pnpm-store || true

BP=workspaces/novnc/workspace.blueprint.json
if [[ -f "$BP" ]]; then
  node - <<'NODE'
  const fs = require('fs');
  const path = require('path');
  const { execSync } = require('child_process');
  const bp = JSON.parse(fs.readFileSync('workspaces/novnc/workspace.blueprint.json', 'utf8'));
  for (const repo of (bp.repos || [])) {
    const { url, path: targetPath, ref } = repo;
    if (!url || !targetPath) continue;
    if (!fs.existsSync(targetPath)) {
      fs.mkdirSync(path.dirname(targetPath), { recursive: true });
      console.log(`[clone] ${url} -> ${targetPath}`);
      execSync(`git clone ${url} ${targetPath}`, { stdio: 'inherit' });
      if (ref) execSync(`git -C ${targetPath} checkout ${ref}`, { stdio: 'inherit' });
    } else {
      console.log(`[skip] exists: ${targetPath}`);
    }
  }
NODE
fi

node -v || true
pnpm -v || true
supabase --version || true
