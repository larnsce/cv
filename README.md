# Lars Schöbitz - website & CV

A data-driven personal website and CV. Content lives in versioned CSV files under
`data/`; a multi-page Quarto website (`*.qmd`) renders to `docs/` for GitHub Pages, and
a separate Typst document renders the PDF CV.

This replaces the earlier single-page CV (and, before that, the `datadrivencv` /
`pagedown` Google Sheet setup). Old files are preserved under `archive/`.

## How it works

```
data/*.csv  ->  R/cv_functions.R  ->  *.qmd  ->  docs/ (website) + cv.pdf
```

Every website page is a thin `.qmd` that sources the R helpers, calls
`create_cv("data")` once, and prints only the sections relevant to that page. The
`section` column in `data/entries.csv` routes each row to a page.

### Pages

| Page | Content |
|------|---------|
| `index.qmd` | Start page (`page-layout: custom`): hero with portrait, role line, intro and contact links; live numbers; upcoming talks and workshops with full dates, event sites and materials links; recent talks; latest writing; explore cards; contact band. All from the aboutme package through `R/cv_functions.R`. |
| `research.qmd` | Publications, conference papers, technical reports, research interests, field research |
| `software.qmd` | Open data & software, grants, awards |
| `teaching.qmd` | Courses, workshops, talks |
| `media.qmd` | Press and video coverage (from `data/media.csv`) |
| `blog.qmd` | Blog posts as external links |
| `cv.qmd` | HTML CV summary with a PDF download button |
| `cv-pdf.qmd` | The full Typst CV; renders to `cv.pdf`. **Not** part of the website render list. |

### Data files

- `data/entries.csv` - every job, project, publication, report, talk. Columns include
  `section` (routes to a page), `type` (`article`, `conference`, `report`, …) and
  `status` (blank = published; `under review` / `work in progress` render as tags).
- `data/media.csv` - press/video coverage (`outlet, date, kind, title, url`).
- `data/contact_info.csv`, `data/language_skills.csv`, `data/technical_skills.csv`,
  `data/text_blocks.csv` - supporting data. `text_blocks.csv` holds the intro bio and
  the per-page intro and prose blocks (research interests, field research, etc.).
- `data/braindump_entries.csv` - work-in-progress rows you fill in by hand; rows still
  containing `TODO` are skipped automatically.

### Assets

- `assets/styles.css` - site chrome and list patterns (navbar, `pub-list`, `pub-tag`,
  `media-list`, `teaching-table`, `section-intro`, `cv-download-btn`, skill bars).
- `assets/theme.scss` - maps the bitz brand palette onto the custom properties that
  `styles.css` reads, and keeps the web base font size at 1rem.
- `assets/landing.scss` - the start page classes (`lse-` prefix: hero, numbers, cards,
  rows, tint and band), modelled on the openwashdata and FAIRqual start pages.
- `onepager/_brand.yml` - the bitz brand file (colours, IBM Plex fonts). The website
  reads it through `brand:` in `_quarto.yml`, the one-pager's Typst template reads it
  directly. Keep it equal to bitzgmbh/brand (`diff` against a clone of that repo).
- `assets/typst-helpers.typ` - Typst helpers (Font Awesome contact lines, skill bars,
  header band) used only by the PDF (`cv-pdf.qmd`).
- `assets/profile-lars-schoebitz.jpg` - profile photo (About page and favicon).

## Building

```
./render.sh
```

This runs three steps: it renders `cv-pdf.qmd` to `cv.pdf` at the repo root, renders
`onepager/cv-onepager.qmd` to `onepager/cv-onepager.pdf` (the one-page CV and
publication list), then renders the website into `docs/` (which picks up both PDFs as
declared resources so the two download buttons on the CV page resolve). The root
`cv.pdf` and `onepager/cv-onepager.pdf` are gitignored build intermediates;
`docs/cv.pdf` and `docs/onepager/cv-onepager.pdf` are the tracked copies. `docs/` is
committed and is what Netlify serves.

To refresh harvested source data (optional): `Rscript scripts/harvest.R` re-pulls ORCID
works and GitHub org repos into `data/staging/` for review. Curated content stays in
`data/*.csv`.

## Deploy

- Netlify serves the pre-built `docs/` folder from `main` (`netlify.toml`: publish
  `docs`, no build command). Merging a PR into `main` triggers a redeploy.
- Custom domain: `www.lse.de` (primary) and `lse.de`, configured in Netlify's domain
  settings; DNS A records at hosttech point both at Netlify.

## Data sources

- Publications, reports, software, datasets: ORCID `0000-0003-2196-5015`, cross-checked
  against the Zotero export `data/my-articles.bib`.
- Open-data projects & packages: GitHub orgs (openwashdata, rstatsZH,
  Global-Health-Engineering, ethopen).
- Roles, courses, workshops, education, media: hand-entered (`data/BRAINDUMP.md`).
