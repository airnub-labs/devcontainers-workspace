# Base
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive

# --- Common base packages (system-level; suitable for Dockerfile) ---
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq \
    xz-utils \
    zip \
    unzip; \
  rm -rf /var/lib/apt/lists/*

# Notes:
# - GUI tooling (Chrome, noVNC, timezone/locale tweaks, etc.) lives in the
#   dedicated novnc-desktop sidecar defined in docker-compose.novnc.yml.
# - The primary devcontainer image stays lean and focused on CLI tooling.
