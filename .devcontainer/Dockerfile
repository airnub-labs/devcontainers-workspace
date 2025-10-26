# Build on your current base
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install Google’s signing key (scoped) and repo the modern, signed-by way
RUN apt-get update && apt-get install -y curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg >/dev/null && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
    https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    google-chrome-stable xterm ffmpeg pulseaudio-utils && \
    rm -rf /var/lib/apt/lists/*

# (optional) make Chrome discoverable to tools that look for CHROME_BIN
ENV CHROME_BIN=/usr/bin/google-chrome
