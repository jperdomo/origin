#!/bin/bash

# Basename
filename="scripts/fedora.sh"
stripped=$(basename "$filename" .sh)
#echo "${stripped##*/}"
echo "$stripped"