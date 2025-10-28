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
- Desktop: Webtop (3001) or noVNC (6080)
- CDP: 9222
- Redis: 6379
- Supabase Studio (when started): 54323