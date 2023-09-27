#!/bin/sh
sudo rclone mount \
--daemon --allow-other --vfs-read-chunk-size=32M \
--poll-interval 15s --vfs-cache-mode writes \
--sftp-ask-password \
NAS: /Users/jperdomo/nfs/NAS