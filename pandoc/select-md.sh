#!/bin/bash

# Source
template="template.docx"
source="source"
output="output"

# Select Arrary
files=($source/*.md)
x=0

while true; do
	if [[ $x -ne ${#files[@]} ]]; then
		files[x]=$(basename ${files[x]})
	else
		break
	fi
	x=$(($x+1))
done

select file in "${files[@]}"; do
if [[ -n "$file" ]]; then
    echo "$file"
    doc=$(echo "$file" | sed 's/\.md$//')

## Output
    #pandoc $source/$file --reference-doc=$template -o $output/$doc.docx
    #$(pandoc "$source/$file" -o "$output/$doc.docx")
    break
    
else
    echo "Invalid option. Try again."
fi

done