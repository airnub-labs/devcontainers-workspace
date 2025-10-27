#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT}/.devcontainer/.env"

declare -a ENV_KEYS=()
declare -A ENV_KEYS_SEEN=()

parse_env_file() {
  local file="$1"
  [[ -f "${file}" ]] || return
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line%%$'\r'}"
    line="$(echo "${line}" | xargs)"
    [[ -z "${line}" ]] && continue
    [[ "${line}" == *=* ]] || continue
    local key="${line%%=*}"
    local value="${line#*=}"
    key="$(echo "${key}" | xargs)"
    value="$(echo "${value}" | xargs)"
    value="$(eval "echo \"${value}\"")"
    export "${key}=${value}"
    if [[ -z "${ENV_KEYS_SEEN[$key]+x}" ]]; then
      ENV_KEYS+=("${key}")
      ENV_KEYS_SEEN["${key}"]=1
    fi
  done < "${file}"
}

parse_env_file "${ROOT}/.devcontainer/.env.example"
parse_env_file "${ROOT}/.env"

PROVIDERS_RAW="${GUI_PROVIDERS:-webtop}"
PROVIDERS="${PROVIDERS_RAW// /}"
if [[ "${PROVIDERS}" == "all" ]]; then
  PROVIDERS="novnc,webtop,chrome"
fi

profiles="devcontainer"
IFS=',' read -ra P <<< "${PROVIDERS}"
for p in "${P[@]}"; do
  case "${p}" in
    novnc)  profiles="${profiles},gui-novnc" ;;
    webtop) profiles="${profiles},gui-webtop" ;;
    chrome) profiles="${profiles},gui-chrome" ;;
    "") ;; # ignore empty entries
    *) echo "[select-gui] Unknown provider: ${p}" >&2; exit 1 ;;
  esac
done

mkdir -p "${ROOT}/.devcontainer"
{
  for key in "${ENV_KEYS[@]}"; do
    [[ "${key}" == "COMPOSE_PROFILES" ]] && continue
    value="${!key-}"
    value="${value//$'\n'/}"
    printf '%s=%s\n' "${key}" "${value}"
  done
  printf 'COMPOSE_PROFILES=%s\n' "${profiles}"
} > "${ENV_FILE}"

echo "[select-gui] GUI_PROVIDERS=${PROVIDERS}"
echo "[select-gui] COMPOSE_PROFILES=${profiles}"
