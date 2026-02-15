#!/bin/bash
set -e

#01:00.0 0300: 10de:2216 (rev a1)
#01:00.1 0403: 10de:1aef (rev a1)

echo "options vfio-pci ids=10de:2216,10de:1aef disable_vga=1" > /etc/modprobe.d/vfio.conf

