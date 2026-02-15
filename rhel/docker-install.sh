#!/bin/bash
set -e

# Detect OS
source /etc/os-release

# Set Docker repo URL based on distro
case "$ID" in
    fedora)
        DOCKER_REPO="https://download.docker.com/linux/fedora/docker-ce.repo"
        ;;
    rhel|centos|rocky|almalinux)
        DOCKER_REPO="https://download.docker.com/linux/centos/docker-ce.repo"
        ;;
    *)
        echo "Unsupported distribution: $ID"
        exit 1
        ;;
esac

# Install Docker
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo "$DOCKER_REPO"
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker

# User Config
sudo usermod -aG docker ${SUDO_USER:-$USER}

# Hello World
sudo docker run hello-world

# Reboot prompt
echo "Reboot required for non sudo docker commands!"
