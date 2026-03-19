#!/bin/bash
# Convert PDF to vertically concatenated PNG
# Usage: pdf2png.sh file1.pdf [file2.pdf ...]

for f in "$@"; do
  [[ "$f" == *.pdf ]] || continue
  dir=$(mktemp -d)
  output="${f%.pdf}.png"
  pdftoppm -png -r 150 "$f" "$dir/page"
  magick "$dir"/page*.png -append "$output"
  rm -rf "$dir"
  echo "Created: $output"
done
