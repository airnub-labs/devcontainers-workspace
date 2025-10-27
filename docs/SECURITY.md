# Security Notes

- Feature installers avoid embedding credentials. CLIs that require tokens (Codex, Claude, Gemini, Supabase) expect environment variables or `supabase login` to be executed by the developer after container start.
- Chrome policies in the `classroom-studio-webtop` template are mounted read-only and can be customized per deployment. Codespaces secrets should be used for API keys when sharing repositories.
- The `docker-in-docker-plus` feature only augments existing Docker-in-Docker setups; it does not start the Docker daemon on its own. Apply it alongside the official `docker-in-docker` feature if privileged builds are required.
- CUDA installation occurs only when `nvidia-smi` is available, preventing failures on hosts without GPU passthrough.
