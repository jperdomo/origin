#!/bin/bash
set -e

sudo apt update

sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

DOCKER_KEY=$(mktemp)
trap 'rm -f "$DOCKER_KEY"' EXIT
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$DOCKER_KEY"
echo "1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570  $DOCKER_KEY" | sha256sum -c - >/dev/null
sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg "$DOCKER_KEY"

CODENAME=$(lsb_release -cs)
if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${CODENAME}/Release" &>/dev/null; then
    echo "No Docker repo for ${CODENAME}, falling back to noble"
    CODENAME="noble"
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

apt-cache policy docker-ce

sudo apt install -y docker-ce docker-compose-plugin

sudo systemctl status docker

sudo usermod -aG docker "${USER}"
