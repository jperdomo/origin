#!/bin/bash

# Select
source="scripts"
cd $source
files=(*.sh)
select file in "${files[@]}"; do
if [[ -n "$file" ]]; then

# Output
  origin=$(echo "$file" | sed 's/\.sh$//')
  echo "
  $origin | origin script running...
  
  " && sleep 1

  # Script
  #echo ./$source/$origin.sh
  bash -c "$(pwd)/$file"
  break
    
# Invalid selection
else
  echo "Invalid selection. Try again."
  exit 1
fi

done