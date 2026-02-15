#!/bin/bash
set -e
sudo dnf update -y
sudo dnf install -y dnf-automatic
sudo dnf-automatic --installupdates