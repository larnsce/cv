#!/usr/bin/env bash
# Render the CV to both HTML (online version) and PDF (via Typst).
# Quarto ships inside RStudio on this machine; adjust QUARTO if you install it standalone.
set -euo pipefail

QUARTO="${QUARTO:-$(command -v quarto || echo /Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto)}"

echo "Using quarto: $QUARTO"
"$QUARTO" render cv.qmd --to html
"$QUARTO" render cv.qmd --to typst

echo "Done: cv.html and cv.pdf"
