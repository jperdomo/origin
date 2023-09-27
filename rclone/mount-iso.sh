#!/bin/bash
source=NAS:OS/template/iso
target=~/iso
rclone mount --daemon $source $target