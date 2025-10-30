# Workspace Architecture (Meta Workspace)

## Role

A thin consumer of catalog **Templates** (“stacks”). It:

- Materializes `.template/.devcontainer/*` from the catalog into `.devcontainer/`.
- Provides a `.code-workspace`.
- Optionally clones app repos into `apps/` (ignored by Git).

## Don’ts

- Do **not** add Features/Templates/Images code here; those live in the catalog.
- Do **not** commit `apps/` contents.
- Do **not** reference folders outside the repo root in the workspace file.

## Health checks (typical stacks)

**📋 See [Ports & Services Reference](./reference/ports-and-services.md) for complete port listings and health check procedures.**

Quick health check ports:
- **GUI Desktop:** Webtop (3001) or noVNC (6080)
- **Chrome DevTools:** 9222 (noVNC), 9223 (Webtop), 9224 (Chrome)
- **Redis:** 6379
- **Supabase Studio:** 54323 (when started)
