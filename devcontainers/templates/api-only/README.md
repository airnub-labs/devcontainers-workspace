# AirNub API workspace template

Designed for backend-focused work that still needs the shared AirNub tooling plus Supabase orchestration.

## What it adds

- Docker-in-Docker with helper scripts to run Supabase services inside the workspace.
- Supabase feature that bootstraps the local stack and synchronises environment variables.
- Persistent Supabase state volume so databases survive container rebuilds.
- Forwarded ports for the Supabase API, Studio, storage, and analytics services alongside Redis and common web app ports.

## When to use it

Choose this template for API or automation repos that do not require the GUI providers. It keeps the base Node.js, pnpm, and Python setup while focusing on backend services.
