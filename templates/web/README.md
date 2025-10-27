# Web Template

Combines the `supabase-cli` and `chrome-cdp` features to create a headless web workspace. Template options let you:

- Pull the prebuilt `ghcr.io/airnub-labs/dev-web` image or build locally (`usePrebuiltImage`). The image digest will be pinned
  once the first public publish completes; until then the templates continue to rely on the `:latest` tag.
- Choose the Chrome release channel and exposed CDP port (`chromeChannel`, `cdpPort`).
