#!/bin/bash
source="/home/user/folder"
remote="user@192.168.0.10"
target="/volume/path/folder"
rsync -azvP $source $remote:$target
#--dry-run