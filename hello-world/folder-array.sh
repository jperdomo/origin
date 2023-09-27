#!/bin/bash

# specify the path to the folder
folder_path="source"

# create an array of filenames in the folder
files=("$folder_path"/*)

# loop through the array and print each filename
for file in "${files[@]}"
do
    echo "$file"
done
