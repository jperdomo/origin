#!/bin/bash
sudo dnf install -y cronie
sudo systemctl start crond.service
sudo systemctl enable crond.service
echo "Use crontab -e to edit"