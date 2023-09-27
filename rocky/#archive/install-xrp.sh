#/bin/bash
sudo dnf install -y xrdp tigervnc-server
sudo systemctl enable --now xrdp
sudo firewall-cmd --add-port=3389/tcp
sudo firewall-cmd --runtime-to-permanent