#!/usr/bin/env bash
set -euo pipefail

ALL="db,auth,rest,realtime,storage,edge-runtime,studio,imgproxy,analytics,inbucket,pgadmin,vector,cron,smtp"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for f in "${ROOT}/.devcontainer/.env.example" "${ROOT}/.env"; do
  if [[ -f "${f}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      line="${line%%#*}"
      line="${line%%$'\r'}"
      line="$(echo "${line}" | xargs)"
      [[ -z "${line}" ]] && continue
      if [[ "${line}" == *=* ]]; then
        key="${line%%=*}"
        value="${line#*=}"
        key="$(echo "${key}" | xargs)"
        value="$(echo "${value}" | xargs)"
        value="$(eval "echo \"${value}\"")"
        export "${key}=${value}"
      fi
    done < "${f}"
  fi
done

INC="${SUPABASE_INCLUDE:-db,auth,rest,realtime,storage,studio}"

mkset() {
  echo "$1" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF'
}

inset() {
  local item="$1"
  local list="$2"
  echo "$list" | tr ',' '\n' | awk 'NF' | grep -x "$item" >/dev/null 2>&1
}

EXC=""
while IFS= read -r service; do
  service="$(echo "${service}" | xargs)"
  [[ -z "${service}" ]] && continue
  if ! inset "${service}" "${INC}"; then
    EXC+="${service},"
  fi
done < <(mkset "${ALL}")

EXC="${EXC%,}"

echo "[supabase] include: ${INC}"
echo "[supabase] exclude: ${EXC:-<none>}"

if [[ -n "${EXC}" ]]; then
  supabase start -x "${EXC}"
else
  supabase start
fi
