#!/bin/bash
set -e

# Docker Group + User
sudo groupadd docker
sudo usermod -aG docker $USER

# Login to group
newgrp docker

# Test
docker run hello-world