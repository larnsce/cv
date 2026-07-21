# Lars Schöbitz - CV

A data-driven CV. Content lives in versioned CSV files under `data/`; the layout is a
Quarto document (`cv.qmd`) that renders to **HTML** (online version) and **PDF** (via Typst).

This replaces the previous `datadrivencv` / `pagedown` setup, which read from a Google
Sheet. The old files are preserved under `archive/`.

## How it works

```
data/*.csv  ->  R/cv_functions.R  ->  cv.qmd  ->  cv.html + cv.pdf
```

- `data/entries.csv` - every job, project, publication, report, talk. The `section`
  column routes each row to a section in `cv.qmd`.
- `data/contact_info.csv`, `data/language_skills.csv`, `data/text_blocks.csv` - supporting data.
- `data/braindump_entries.csv` - work-in-progress rows you fill in by hand (see
  `data/BRAINDUMP.md`). Rows still containing `TODO` are skipped automatically.

## Updating the CV

1. **Refresh harvested data** (optional): `Rscript scripts/harvest.R` re-pulls ORCID works
   and GitHub org repos into `data/staging/` for review. Curated content stays in `data/*.csv`.
2. **Edit** the relevant CSV in `data/`.
3. **Render**: `./render_cv.sh` (produces `cv.html` and `cv.pdf`).

## Sections

`work_experience, education, open_data_software, teaching, workshops, talks,
publications, conference_papers, technical_reports, professional_roles, references`.

Set a row's `end` column empty to mark it as current. Entries sort newest-first.

## Data sources

- Publications, reports, software, datasets: ORCID `0000-0003-2196-5015`.
- Open-data projects & packages: GitHub orgs (openwashdata, rstatsZH,
  Global-Health-Engineering, ethopen).
- Roles, courses, workshops, education: hand-entered (`data/BRAINDUMP.md`).
