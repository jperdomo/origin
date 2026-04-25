#!/bin/bash
set -e

sudo apt update

sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

CODENAME=$(lsb_release -cs)
if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${CODENAME}/Release" &>/dev/null; then
    echo "No Docker repo for ${CODENAME}, falling back to noble"
    CODENAME="noble"
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

apt-cache policy docker-ce

sudo apt install -y docker-ce docker-compose

sudo systemctl status docker

sudo usermod -aG docker "${USER}"
