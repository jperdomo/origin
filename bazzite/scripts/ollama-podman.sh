#!/bin/bash
set -e

# Idempotent: skip if the container already exists (so re-runs don't error).
if podman container exists ollama 2>/dev/null; then
    echo "ollama container already exists; starting it if stopped."
    podman start ollama >/dev/null 2>&1 || true
    exit 0
fi

podman run -d --name ollama --label "io.containers.autoupdate=registry" --restart=unless-stopped --security-opt label=type:container_runtime_t -p 127.0.0.1:11434:11434 -v ollama:/root/.ollama --device /dev/kfd --device /dev/dri -e HSA_OVERRIDE_GFX_VERSION="10.3.0" docker.io/ollama/ollama:rocm
