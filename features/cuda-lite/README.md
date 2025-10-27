# CUDA Lite Feature

Detects whether the container has access to an NVIDIA GPU (via `nvidia-smi`). If present, installs the Ubuntu `nvidia-cuda-toolkit` package and exposes CUDA paths through `/etc/profile.d/cuda-lite.sh`. If no GPU is detected, the feature exits cleanly and annotates the install footprint.

Codespaces currently virtualizes GPUs for select SKUs only; environments without GPU passthrough will see `CUDA_AVAILABLE=false` in the shell profile.
