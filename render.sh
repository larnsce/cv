#!/usr/bin/env bash
# Build the site. Two steps, in order:
#   1. Render the Typst CV to cv.pdf at the repo root (cv-pdf.qmd is NOT part of
#      the website render list, so the site build never sweeps it up).
#   2. Render the Quarto website into docs/. cv.pdf is a declared resource, so it
#      is copied into docs/cv.pdf and the CV page's download button resolves.
# Quarto ships inside RStudio on this machine; adjust QUARTO if you install it standalone.
set -euo pipefail

QUARTO="${QUARTO:-$(command -v quarto || echo /Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto)}"

echo "Using quarto: $QUARTO"

echo "==> Rendering PDF (cv-pdf.qmd -> cv.pdf)"
"$QUARTO" render cv-pdf.qmd --to typst

echo "==> Rendering website (-> docs/)"
"$QUARTO" render

echo "Done: docs/ site built, cv.pdf shipped to docs/cv.pdf"
