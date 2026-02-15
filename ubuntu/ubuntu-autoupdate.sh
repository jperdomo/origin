#!/bin/bash
set -e
# Ubuntu Automatic Security Updates Setup Script

# Install unattended-upgrades if not already installed
sudo apt update
sudo apt install -y unattended-upgrades apt-listchanges

# Enable automatic updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure unattended-upgrades
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
    // Add packages you don't want auto-updated here
    // "vim";
    // "libc6";
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "01:30";
EOF

# Configure auto-upgrade settings with 1am schedule
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Configure systemd timer to run at 1am
sudo mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d/
sudo tee /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf > /dev/null <<'EOF'
[Timer]
OnCalendar=
OnCalendar=01:00
RandomizedDelaySec=0
EOF

# Reload systemd and restart timer
sudo systemctl daemon-reload
sudo systemctl restart apt-daily-upgrade.timer

echo "✅ Unattended upgrades configured successfully!"
echo "Updates will run daily at 1:00 AM"
echo "System will auto-reboot if needed at 1:30 AM"