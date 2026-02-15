#!/bin/bash
echo "What is the new hostname?"
read -r hostname
hostnamectl set-hostname "$hostname"
echo "hostname set to: $(hostname)"
