# One-off migration: add `type` and `status` columns to data/entries.csv and
# correct one blog URL to its official ghe.ethz.ch location.
# Run once from the repo root: Rscript scripts/migrate_add_pub_columns.R
# Safe to re-run: it is idempotent (checks before adding columns).

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

path <- "data/entries.csv"
e <- read_csv(path, show_col_types = FALSE)

# --- add `type` (publication subtype) -------------------------------------
# article | preprint | dataset | book | chapter | report. Blank elsewhere.
if (!"type" %in% names(e)) e$type <- NA_character_
e <- e |>
  mutate(type = case_when(
    section == "publications"      & (is.na(type) | type == "") ~ "article",
    section == "conference_papers" & (is.na(type) | type == "") ~ "conference",
    section == "technical_reports" & (is.na(type) | type == "") ~ "report",
    TRUE ~ type
  ))

# --- add `status` (publication status) ------------------------------------
# empty = published. under review | work in progress | in prep for future rows.
if (!"status" %in% names(e)) e$status <- NA_character_

# --- fix the one blog URL with a confirmed official ghe.ethz.ch location ---
old_url <- "https://ghe-open.ch/blog/posts/2024-02-13-data-steward/"
new_url <- "https://ghe.ethz.ch/ghe-blog-news/2024/02/blog-attention-prof-you-need-a-data-steward-for-your-team.html"
e$url[!is.na(e$url) & e$url == old_url] <- new_url

# Keep column order stable: original columns, then type, status appended.
orig <- c("section","title","loc","institution","start","end",
          "description_1","description_2","description_3","url")
e <- e[c(orig, "type", "status")]

write_csv(e, path, na = "")
message("Migrated ", path, ": ", nrow(e), " rows, columns: ",
        paste(names(e), collapse = ", "))
