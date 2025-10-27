FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG NODE_VERSION=24
ENV NODE_VERSION=${NODE_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates git build-essential \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable pnpm

ENV PNPM_HOME=/home/vscode/.local/share/pnpm
ENV PATH=${PNPM_HOME}:${PATH}
RUN mkdir -p "${PNPM_HOME}" && chown vscode:vscode "${PNPM_HOME}"

USER vscode
RUN pnpm config set store-dir /home/vscode/.pnpm-store
USER root

CMD ["/bin/bash"]
