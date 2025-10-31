# Catalog Consumption Guide

This guide explains how the Meta Workspace consumes Templates from the DevContainers catalog, including the materialization process, troubleshooting, and best practices.

> **⚠️ Customization Note:**
> This guide uses `airnub-labs/devcontainers-catalog` as an example catalog repository. You can customize this by setting the `CATALOG_REPO` environment variable to point to your own catalog or fork.

---

## Overview

The Meta Workspace uses a **materialization pattern** to consume Dev Container Templates from a centralized catalog:

1. Template definitions live in your catalog repository (e.g., `airnub-labs/devcontainers-catalog`)
2. This workspace fetches and extracts the chosen Template
3. Template content replaces `.devcontainer/` in this repo
4. VS Code/Codespaces uses the materialized `.devcontainer/` to build the environment

**Benefits:**
- ✅ Single source of truth for environment definitions
- ✅ Version control for Templates (via git tags/commits)
- ✅ Easy updates across multiple workspace repos
- ✅ No git submodules or complex dependency management

---

## Quick Start

### Basic Usage

```bash
# Sync a template using default catalog reference (main branch)
TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Sync with specific catalog version
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop scripts/sync-from-catalog.sh

# Sync from specific commit
CATALOG_REF=abc123def TEMPLATE=stack-nextjs-supabase-novnc scripts/sync-from-catalog.sh
```

### Available Templates

Check the catalog repository for current templates:
- `stack-nextjs-supabase-webtop` - Full desktop with Webtop (HTTPS, audio)
- `stack-nextjs-supabase-novnc` - Lightweight noVNC desktop
- More templates may be available - see catalog README

---

## Materialization Process

### What Happens During Sync

```
1. Environment Variables Read
   ├─ CATALOG_REF (default: main)
   ├─ TEMPLATE (required)
   └─ CATALOG_REPO (default: airnub-labs/devcontainers-catalog)

2. Download Catalog Tarball
   ├─ URL: https://github.com/$CATALOG_REPO/archive/$CATALOG_REF.tar.gz
   ├─ Saved to: /tmp/catalog-$TEMPLATE-$$.tar.gz
   └─ Progress: Displayed if curl supports it

3. Extract Template Directory
   ├─ Find: $CATALOG_NAME/templates/$TEMPLATE/
   ├─ Extract to: /tmp/catalog-extract-$$/
   └─ Validate: Ensure devcontainer.json exists

4. Backup Existing .devcontainer
   ├─ If exists: Move to .devcontainer.backup-$(date)
   ├─ Prevents data loss on sync failure
   └─ Can be restored manually if needed

5. Materialize Template
   ├─ Copy extracted template to .devcontainer/
   ├─ Preserve permissions and structure
   └─ Replace all previous content

6. Cleanup
   ├─ Remove temporary files
   ├─ Remove extraction directory
   └─ Keep backup for safety

7. Success
   └─ .devcontainer/ now contains Template content
```

---

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TEMPLATE` | ✅ Yes | (none) | Template name from catalog |
| `CATALOG_REF` | No | `main` | Git ref (tag, branch, commit) to fetch |
| `CATALOG_REPO` | No | `airnub-labs/devcontainers-catalog` | GitHub repository |

### Examples

```bash
# Production: Use tagged version
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Development: Use main branch (latest)
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Testing: Use feature branch
CATALOG_REF=feature/new-gui TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Rollback: Use specific commit
CATALOG_REF=abc123def456 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh
```

---

## Reproducibility

### Version Pinning

**For production workspaces, always pin `CATALOG_REF` to a specific tag or commit:**

```bash
# ✅ Good: Pinned to tag
CATALOG_REF=v1.2.3 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# ✅ Good: Pinned to commit SHA
CATALOG_REF=a1b2c3d4e5f6 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# ⚠️ Risky: Uses latest main (may change)
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh
```

### Lock Files

Some stacks may publish `stack.lock.json` to pin:
- Feature versions
- Image digests
- Dependency versions

When present, the lock file ensures consistent builds across time.

### Recommended Workflow

1. **Development:** Use `CATALOG_REF=main` for latest changes
2. **Testing:** Pin to specific commit for validation
3. **Production:** Pin to tagged release (e.g., `v1.2.3`)
4. **Document:** Record which version you're using in your team docs

---

## Troubleshooting

### Sync Fails with "Template not found"

**Symptom:**
```
Error: Template 'stack-nextjs-supabase-webtop' not found in catalog
```

**Causes:**
- Template name misspelled
- Template doesn't exist in the specified `CATALOG_REF`
- Extraction directory structure changed

**Solutions:**
```bash
# List available templates
curl -sL "https://github.com/airnub-labs/devcontainers-catalog/archive/main.tar.gz" | \
  tar -tzf - | grep "templates/"

# Check template name spelling
echo $TEMPLATE

# Try with main branch
CATALOG_REF=main TEMPLATE=your-template scripts/sync-from-catalog.sh

# Verify catalog repository is accessible
curl -I "https://github.com/airnub-labs/devcontainers-catalog"
```

---

### Download Fails or Times Out

**Symptom:**
```
curl: (28) Operation timed out
```

**Causes:**
- Network connectivity issues
- GitHub is down or rate-limiting
- Firewall blocking GitHub access
- Large tarball on slow connection

**Solutions:**
```bash
# Check GitHub status
curl -I "https://github.com"

# Test download manually
curl -L "https://github.com/airnub-labs/devcontainers-catalog/archive/main.tar.gz" \
  -o /tmp/test-catalog.tar.gz

# Retry with increased timeout
timeout 300 scripts/sync-from-catalog.sh

# Use different network/VPN if firewall is blocking

# Check for rate limiting
curl -I "https://api.github.com/rate_limit"
```

---

### Corrupted or Incomplete Download

**Symptom:**
```
tar: Unexpected EOF in archive
tar: Error is not recoverable: exiting now
```

**Causes:**
- Download interrupted
- Corrupted tarball
- Disk space issues

**Solutions:**
```bash
# Check disk space
df -h

# Remove temporary files
rm -f /tmp/catalog-*.tar.gz
rm -rf /tmp/catalog-extract-*

# Retry sync
CATALOG_REF=main TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Download manually to verify
curl -L "https://github.com/airnub-labs/devcontainers-catalog/archive/main.tar.gz" \
  -o /tmp/manual-catalog.tar.gz
tar -tzf /tmp/manual-catalog.tar.gz | head
```

---

### .devcontainer/ Becomes Empty After Sync

**Symptom:**
- `.devcontainer/` directory is empty or missing files
- Container build fails with "devcontainer.json not found"

**Causes:**
- Sync script failed mid-operation
- Template structure doesn't match expected format
- Permissions issues

**Solutions:**
```bash
# Check if backup exists
ls -la .devcontainer.backup-*

# Restore from backup
mv .devcontainer.backup-YYYY-MM-DD-HHMMSS .devcontainer

# Or restore from git
git restore .devcontainer/

# Retry sync with verbose output
bash -x scripts/sync-from-catalog.sh
```

---

### Permission Denied Errors

**Symptom:**
```
permission denied: .devcontainer/
```

**Causes:**
- Running script without write permissions
- Directory owned by different user
- Filesystem mounted read-only

**Solutions:**
```bash
# Check current permissions
ls -la .devcontainer

# Fix ownership (adjust username)
sudo chown -R $USER:$USER .devcontainer

# Verify you can write
touch .devcontainer/test && rm .devcontainer/test

# Check mount options
mount | grep $(pwd)
```

---

## Best Practices

### 1. Pin Versions in Production

```bash
# ✅ Create a wrapper script for your team
cat > sync-prod-template.sh << 'EOF'
#!/bin/bash
# Production template sync - pinned version
CATALOG_REF=v1.2.3
TEMPLATE=stack-nextjs-supabase-webtop
export CATALOG_REF TEMPLATE
exec scripts/sync-from-catalog.sh
EOF
chmod +x sync-prod-template.sh
```

### 2. Document Your Template Version

```bash
# Add to your README or docs
echo "Current template: stack-nextjs-supabase-webtop@v1.2.3" >> .devcontainer/VERSION
```

### 3. Test Before Deploying to Team

```bash
# Test in a branch first
git checkout -b test-template-update
CATALOG_REF=v1.3.0 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Rebuild container and test
devcontainer up --remove-existing-container

# If successful, merge to main
git add .devcontainer/
git commit -m "Update template to v1.3.0"
git checkout main
git merge test-template-update
```

### 4. Backup Before Major Updates

```bash
# Manual backup before sync
cp -r .devcontainer .devcontainer.manual-backup-$(date +%Y%m%d)

# Sync
CATALOG_REF=v2.0.0 TEMPLATE=stack-nextjs-supabase-webtop \
  scripts/sync-from-catalog.sh

# Test, and restore if needed
# mv .devcontainer.manual-backup-20251030 .devcontainer
```

### 5. Keep Sync Script Updated

The sync script itself may receive updates. Periodically check the catalog repository for improvements:

```bash
# Check for script updates
curl -sL "https://github.com/airnub-labs/devcontainers-catalog/raw/main/scripts/sync-from-catalog.sh" \
  > /tmp/latest-sync.sh
diff scripts/sync-from-catalog.sh /tmp/latest-sync.sh
```

---

## Advanced Usage

### Using a Fork or Different Catalog

```bash
# Use your organization's fork
CATALOG_REPO=your-org/devcontainers-catalog \
CATALOG_REF=main \
TEMPLATE=your-custom-stack \
  scripts/sync-from-catalog.sh
```

### Automated Sync in CI/CD

```yaml
# Example: GitHub Actions workflow
name: Update Dev Container Template
on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  sync-template:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Sync latest template
        env:
          CATALOG_REF: v1.2.3  # Pin to specific version
          TEMPLATE: stack-nextjs-supabase-webtop
        run: scripts/sync-from-catalog.sh

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: 'chore: update dev container template'
          title: 'Update Dev Container Template'
          body: 'Automated template sync from catalog'
```

### Verifying Template Integrity

```bash
# After sync, verify key files exist
test -f .devcontainer/devcontainer.json && echo "✓ devcontainer.json found"
test -f .devcontainer/docker-compose.yml && echo "✓ docker-compose.yml found"

# Validate JSON syntax
jq empty .devcontainer/devcontainer.json && echo "✓ Valid JSON"

# Check for required fields
jq -e '.name' .devcontainer/devcontainer.json && echo "✓ Has name"
jq -e '.dockerComposeFile' .devcontainer/devcontainer.json && echo "✓ Has compose file"
```

---

## Related Documentation

- **[Architecture Overview](./architecture/overview.md)** - How catalog materialization fits into the system
- **[Core Concepts](./getting-started/concepts.md)** - Understanding Templates, Stacks, and the Catalog
- **[Troubleshooting](./reference/troubleshooting.md)** - General workspace troubleshooting
- **[Development Roadmap](./development/roadmap.md)** - Catalog structure and packaging

---

## Script Reference

### Location
`scripts/sync-from-catalog.sh`

### Usage
```bash
CATALOG_REF=<ref> TEMPLATE=<template-name> scripts/sync-from-catalog.sh
```

### Exit Codes
- `0` - Success
- `1` - Missing required environment variables
- `2` - Template not found in catalog
- `3` - Download failed
- `4` - Extraction failed

### Temporary Files
- `/tmp/catalog-$TEMPLATE-$$.tar.gz` - Downloaded tarball
- `/tmp/catalog-extract-$$/` - Extraction directory
- `.devcontainer.backup-YYYY-MM-DD-HHMMSS` - Backup of previous .devcontainer

All temporary files are cleaned up automatically unless the script fails.

---

**Last updated:** 2025-10-30
