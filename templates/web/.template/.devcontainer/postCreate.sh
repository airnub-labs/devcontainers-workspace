#!/usr/bin/env bash
set -euo pipefail

if command -v pnpm >/dev/null 2>&1 && [ -f package.json ]; then
  pnpm install --frozen-lockfile || pnpm install
fi

if command -v supabase >/dev/null 2>&1; then
  supabase --version || true
fi
