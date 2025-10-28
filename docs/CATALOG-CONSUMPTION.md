# Consuming the Catalog

Use `scripts/sync-from-catalog.sh` to fetch a tarball from `airnub-labs/devcontainers-catalog` and materialize the chosen Template payload into `.devcontainer/`.

Examples:

```bash
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh
TEMPLATE=stack-nextjs-supabase-novnc scripts/sync-from-catalog.sh
```

Pin `CATALOG_REF` to a tag/commit for reproducibility.
