# Next.js + Supabase Template

Extends the base web workspace with optional Next.js scaffolding. Template options let you:

- Reuse the published `dev-web` image or build locally (`usePrebuiltImage`). A pinned digest will be added after the first
  public publish of the image; until then the templates reference the `:latest` tag.
- Select the Chrome channel/port for the CDP feature (`chromeChannel`, `cdpPort`).
- Decide whether to install the agent tooling CLI suite (`includeAgentToolingClis`).
- Scaffold a Next.js app with version, TypeScript, App Router, and Supabase auth defaults (`scaffold`, `nextVersion`, `ts`, `appRouter`, `auth`).
