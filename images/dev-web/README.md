# dev-web Image

Bundles the Node.js 24 + pnpm setup used by `dev-base`, adds headless browser dependencies (fonts and Chrome runtime libraries), and pre-seeds the Google Chrome apt repository for faster provisioning by the `chrome-cdp` feature. When publishing images you can still override `BASE_IMAGE` to point at a prebuilt `dev-base` artifact.
