#!/bin/bash
set -e

sudo setsebool -P container_use_devices=true

#sudo podman run -it --name ollama   --replace  -p 127.0.0.1:11434:11434 -v ollama:/root/.ollama --device /dev/kfd --device /dev/dri   docker.io/ollama/ollama:rocm

podman run -d --name ollama --label "io.containers.autoupdate=registry" --restart=unless-stopped -p 127.0.0.1:11434:11434 -v ollama:/root/.ollama --device /dev/kfd --device /dev/dri -e HSA_OVERRIDE_GFX_VERSION="10.3.0" docker.io/ollama/ollama:rocm
