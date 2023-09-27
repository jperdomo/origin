#!/bin/bash
echo What is the new hostname?
read hostname
hostnamectl set-hostname $hostname
echo hostname set to: $(hostname)