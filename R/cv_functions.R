# cv_functions.R
# Read CV data from data/*.csv and render sections as markdown.
# Replaces the old cv_printing_functions.r (Google Sheets) with a CSV-backed version.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(glue)
  library(stringr)
})

#' Load all CV data from the data/ folder into a list.
create_cv <- function(data_dir = "data") {
  rd <- function(f) suppressMessages(read_csv(file.path(data_dir, f), show_col_types = FALSE))

  entries <- rd("entries.csv")

  # Merge in the brain-dump entries once their TODOs are filled.
  bd_path <- file.path(data_dir, "braindump_entries.csv")
  if (file.exists(bd_path)) {
    bd <- suppressMessages(read_csv(bd_path, show_col_types = FALSE))
    bd <- dplyr::filter(bd, !dplyr::if_any(dplyr::everything(), ~ .x == "TODO"))
    if (nrow(bd) > 0) entries <- dplyr::bind_rows(entries, bd)
  }

  # Collapse description_1..N into a single bulleted block.
  desc_cols <- grep("^description", names(entries), value = TRUE)
  entries$bullets <- apply(entries[desc_cols], 1, function(r) {
    r <- r[!is.na(r) & r != "" & r != "TODO"]
    if (length(r) == 0) return("")
    paste0("- ", paste(r, collapse = "\n- "))
  })

  # Sort newest first by `end`, then `start`; blank end = current = top.
  yr <- function(x) suppressWarnings(as.integer(str_extract(as.character(x), "(19|20)\\d{2}")))
  entries <- entries |>
    mutate(.end = ifelse(is.na(end) | end == "", 9999L, yr(end)),
           .start = yr(start)) |>
    arrange(desc(.end), desc(.start))

  list(
    entries = entries,
    skills  = rd("language_skills.csv"),
    text    = rd("text_blocks.csv"),
    contact = rd("contact_info.csv")
  )
}

#' Format a start-end pair into a timeline string.
timeline <- function(start, end) {
  s <- ifelse(is.na(start) | start == "", NA, as.character(start))
  e <- ifelse(is.na(end)   | end   == "", NA, as.character(end))
  dplyr::case_when(
    is.na(s) & is.na(e) ~ "N/A",
    is.na(e)            ~ paste0(s, " - Current"),
    s == e             ~ e,
    is.na(s)            ~ e,
    TRUE                ~ paste0(e, " - ", s)  # kept newest-left for consistency
  )
}

#' Print one section of entries as markdown (call with results='asis').
print_section <- function(cv, section_id) {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (nrow(d) == 0) return(invisible())
  d$tl <- timeline(d$start, d$end)
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    ttl <- if (!is.na(r$url) && r$url != "") glue("[{r$title}]({r$url})") else r$title
    cat(glue("### {ttl}\n\n"))
    if (!is.na(r$loc) && r$loc != "") cat(r$loc, "\n\n")
    if (!is.na(r$institution) && r$institution != "") cat(r$institution, "\n\n")
    if (!is.na(r$tl) && r$tl != "") cat(r$tl, "\n\n")
    if (r$bullets != "") cat(r$bullets, "\n\n")
    cat("\n\n")
  }
  invisible()
}

#' Print a named text block.
print_text_block <- function(cv, label) {
  t <- dplyr::filter(cv$text, loc == label)$text
  if (length(t)) cat(t)
  invisible()
}

#' Print contact info as a bulleted list with Font Awesome icons.
print_contact <- function(cv) {
  for (i in seq_len(nrow(cv$contact))) {
    r <- cv$contact[i, ]
    cat(glue("- <i class='fa fa-{r$icon}'></i> {r$contact}\n"))
  }
  invisible()
}

#' Print skill bars.
print_skills <- function(cv, out_of = 5) {
  for (i in seq_len(nrow(cv$skills))) {
    r <- cv$skills[i, ]
    pct <- round(100 * as.numeric(r$level) / out_of)
    cat(glue(
      "<div class='skill-bar' style=\"background:linear-gradient(to right,",
      "#969696 {pct}%, #d9d9d9 {pct}% 100%)\">{r$skill}</div>\n"
    ))
  }
  invisible()
}
