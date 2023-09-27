#!/bin/bash
echo Current rclone remotes:
rclone listremotes
echo What is the source? ex. NAS:OS/template/iso
read source
echo What is the target? ex. ~/iso
read target
rclone mount --daemon $source $target