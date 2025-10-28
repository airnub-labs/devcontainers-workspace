# Workspace Architecture (Meta Workspace)


## Role
A thin consumer of catalog **Templates** (stacks). It:
- Materializes `.template/.devcontainer/*` from a chosen catalog template into `.devcontainer/`.
- Provides a `.code-workspace` for the project.
- Optionally clones app repos via `workspace.blueprint.json` in `postCreate`.


## Don’ts
- Do **not** install services in Feature installers.
- Do **not** commit `apps/` contents (cloned on demand).
- Do **not** fork the catalog inside this repo; sync via the tarball script.


## Health checks
- Desktop: Webtop (3001) or noVNC (6080)
- CDP: 9222
- Redis: 6379
- Supabase Studio (when local started): 54323
