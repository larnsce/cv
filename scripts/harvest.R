# harvest.R
# Re-pull CV source data from ORCID and GitHub into staging CSVs under data/staging/.
# These staging files are for REVIEW. Curated content lives in data/*.csv, which you
# edit by hand after comparing against the staging pull. Run: Rscript scripts/harvest.R
#
# Requires: httr2, jsonlite, dplyr, readr, purrr, tibble, and the `gh` CLI on PATH.

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(purrr)
  library(tibble)
})

ORCID_ID <- "0000-0003-2196-5015"
ORGS     <- c("openwashdata", "rstatsZH", "Global-Health-Engineering", "ethopen")

staging_dir <- "data/staging"
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

# ---- ORCID ------------------------------------------------------------------
message("Harvesting ORCID works for ", ORCID_ID, " ...")

orcid <- request(paste0("https://pub.orcid.org/v3.0/", ORCID_ID, "/works")) |>
  req_headers(Accept = "application/json") |>
  req_perform() |>
  resp_body_json()

pluck_ext <- function(summary, type) {
  ids <- summary[["external-ids"]][["external-id"]] %||% list()
  hit <- purrr::detect(ids, ~ identical(tolower(.x[["external-id-type"]]), type))
  if (is.null(hit)) NA_character_ else hit[["external-id-value"]]
}

orcid_rows <- map_dfr(orcid$group, function(g) {
  s <- g[["work-summary"]][[1]]
  tibble(
    year    = s[["publication-date"]][["year"]][["value"]] %||% NA_character_,
    type    = s[["type"]] %||% NA_character_,
    title   = s[["title"]][["title"]][["value"]] %||% NA_character_,
    journal = s[["journal-title"]][["value"]] %||% NA_character_,
    doi     = pluck_ext(s, "doi"),
    put_code = s[["put-code"]]
  )
}) |>
  arrange(desc(year))

write_csv(orcid_rows, file.path(staging_dir, "orcid_works.csv"))
message("  wrote ", nrow(orcid_rows), " works -> ", file.path(staging_dir, "orcid_works.csv"))

# ---- GitHub orgs (via gh CLI) ----------------------------------------------
gh_repos <- function(org) {
  jq <- paste0(
    '.[] | select(.fork==false) | ',
    '{name, description, homepage, stars: .stargazers_count, updated: .updated_at, archived}'
  )
  raw <- system2(
    "gh",
    c("api", shQuote(paste0("orgs/", org, "/repos?per_page=100&sort=updated")),
      "--jq", shQuote(jq)),
    stdout = TRUE, stderr = FALSE
  )
  if (length(raw) == 0) return(tibble())
  map_dfr(raw, ~ as_tibble(fromJSON(.x))) |> mutate(org = org, .before = 1)
}

message("Harvesting GitHub repos for orgs: ", paste(ORGS, collapse = ", "), " ...")
gh_rows <- map_dfr(ORGS, gh_repos) |>
  arrange(org, desc(stars), desc(updated))

write_csv(gh_rows, file.path(staging_dir, "github_repos.csv"))
message("  wrote ", nrow(gh_rows), " repos -> ", file.path(staging_dir, "github_repos.csv"))

message("\nDone. Review data/staging/*.csv, then hand-curate data/*.csv.")
