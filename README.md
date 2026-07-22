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
| `index.qmd` | About: headshot, intro bio, profile links (trestles template) |
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

### Styling

- `styles.css` - site chrome and list patterns (navbar, `pub-list`, `pub-tag`,
  `media-list`, `teaching-table`, `section-intro`, `cv-download-btn`, skill bars).
- `typst-helpers.typ` - Typst helpers (Font Awesome contact lines, skill bars, header
  band) used only by the PDF (`cv-pdf.qmd`).

## Building

```
./render.sh
```

This runs two steps: it renders `cv-pdf.qmd` to `cv.pdf`, then renders the website into
`docs/` (which picks up `cv.pdf` as a declared resource so the CV page's download button
resolves). `docs/` is committed and is the GitHub Pages source.

To refresh harvested source data (optional): `Rscript scripts/harvest.R` re-pulls ORCID
works and GitHub org repos into `data/staging/` for review. Curated content stays in
`data/*.csv`.

## Deploy

- GitHub Pages: Settings → Pages → Source: `main` branch, `/docs` folder.
- Custom domain: `CNAME` contains `www.lse.de`; point that DNS record at GitHub Pages.

## Data sources

- Publications, reports, software, datasets: ORCID `0000-0003-2196-5015`.
- Open-data projects & packages: GitHub orgs (openwashdata, rstatsZH,
  Global-Health-Engineering, ethopen).
- Roles, courses, workshops, education, media: hand-entered (`data/BRAINDUMP.md`).
