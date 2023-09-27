#!/bin/bash
#Install Docker
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo \
https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
#User Config
sudo usermod -aG docker $USER
#Hello World
sudo docker run hello-world
#Reboor prompt
echo Reboot required for non sudo docker commands!