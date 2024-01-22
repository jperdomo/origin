#!/bin/bash

# Define the list of available scripts
scripts=("script1.sh" "script2.sh" "script3.sh")

# Print the menu
echo "Please select a script to run:"
for i in "${!scripts[@]}"; do
  printf "%s) %s\n" "$((i+1))" "${scripts[$i]}"
done

# Get user input
read -r selection

# Validate user input
if ! [[ "$selection" =~ ^[1-9][0-9]*$ ]] || (( selection < 1 )) || (( selection > ${#scripts[@]} )); then
  echo "Invalid selection."
  exit 1
fi

# Run selected script
selected_script="${scripts[$((selection-1))]}"
echo "Running $selected_script..."
./"$selected_script"
