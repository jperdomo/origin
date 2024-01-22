#!/bin/bash

if [ "$UID" -eq 0 ]; then
  echo "You are the root user."
else
  echo "You are not the root user."
fi
