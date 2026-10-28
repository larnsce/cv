#!/usr/bin/env bash
# Build the site. Three steps, in order:
#   1. Render the Typst CV to cv.pdf at the repo root (cv-pdf.qmd is NOT part of
#      the website render list, so the site build never sweeps it up).
#   2. Render the one-page CV and publication list to onepager/cv-onepager.pdf
#      (same idea: rendered from its own folder, not part of the website list).
#   3. Render the Quarto website into docs/. cv.pdf and onepager/cv-onepager.pdf
#      are declared resources, so they are copied into docs/ and the two download
#      buttons on the CV page resolve.
# Quarto ships inside RStudio on this machine; adjust QUARTO if you install it standalone.
set -euo pipefail

QUARTO="${QUARTO:-$(command -v quarto || echo /Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto)}"

echo "Using quarto: $QUARTO"

echo "==> Rendering PDF (cv-pdf.qmd -> cv.pdf)"
"$QUARTO" render cv-pdf.qmd --to typst

echo "==> Rendering one-page CV (onepager/cv-onepager.qmd -> onepager/cv-onepager.pdf)"
(cd onepager && "$QUARTO" render cv-onepager.qmd --to typst)

echo "==> Rendering website (-> docs/)"
# The site pages read the aboutme package, not files in this repo, so Quarto's
# freeze cache (freeze: auto) would keep stale page output when only the
# package changed. Drop the cache so every page re-executes.
rm -rf _freeze
"$QUARTO" render

echo "Done: docs/ site built, cv.pdf and onepager/cv-onepager.pdf shipped into docs/"
