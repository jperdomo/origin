#!/bin/bash

# Define the list of options
options=("Option 1" "Option 2" "Option 3")

# Print the menu
echo "Please select an option:"
for i in "${!options[@]}"; do
  printf "%s) %s\n" "$((i+1))" "${options[$i]}"
done

# Get user input
read -r selection

# Validate user input
if ! [[ "$selection" =~ ^[1-9][0-9]*$ ]] || (( selection < 1 )) || (( selection > ${#options[@]} )); then
  echo "Invalid selection."
  exit 1
fi

# Process user input
selected_option="${options[$((selection-1))]}"
echo "You selected: $selected_option"
