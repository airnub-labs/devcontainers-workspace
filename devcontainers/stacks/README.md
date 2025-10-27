# AirNub devcontainer stacks

The stacks catalogue bundles templates and features into opinionated profiles for different deployment scenarios. Each stack reuses the `templates/base` foundation so Node.js, Python, and pnpm remain consistent across the workspace.

## Stack matrix

| Stack | Templates | Key features | Primary use case |
| ----- | --------- | ------------ | ---------------- |
| Classroom | base → full-gui | GUI tooling, Docker-in-Docker helpers, Supabase stack | Instructor-led sessions that need an in-container browser and Supabase services |
| Production API | base → api-only | Docker-in-Docker helpers, Supabase stack | Backend or automation repos targeting production-like environments |

## Device & browser support

| Stack | Desktop VS Code | Codespaces (Chrome/Edge/Firefox) | iPadOS Safari | Android Chrome |
| ----- | --------------- | -------------------------------- | ------------- | ------------- |
| Classroom | ✅ Recommended | ✅ Recommended | ⚠️ Supported with external keyboard | ⚠️ Supported for light dashboards |
| Production API | ✅ Recommended | ✅ Recommended | ⚠️ Terminal-only workflows | ⚠️ Terminal-only workflows |

## Required ports

| Stack | Forwarded ports |
| ----- | --------------- |
| Classroom | 3000, 3100, 54321-54327, 6080, 6081, 6379, 9222 |
| Production API | 3000, 3100, 54321-54327, 6379 |

For details on how these stacks map onto the workspace architecture, see [../../docs/workspace-architecture.md](../../docs/workspace-architecture.md).
