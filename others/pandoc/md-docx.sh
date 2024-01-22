#!/bin/bash
md=source.md
template=custom-reference.docx
output=test.docx
pandoc $md --reference-doc=$template -o $output