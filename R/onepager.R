# Helpers for the one-page CV and the one-page publication list in
# onepager/cv-onepager.qmd. They read the aboutme data package, like
# cv_functions.R, and emit markdown or raw Typst for Quarto's Typst output.

library(dplyr)
library(stringr)
library(glue)

# Escape the characters Typst markup treats specially. URLs never go through
# here: they are passed as strings to #link(), which keeps "//" out of markup.
typst_esc <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x, perl = TRUE)
  gsub("([#*_`$<>@\\[\\]~])", "\\\\\\1", x, perl = TRUE)
}

typst_link <- function(url, label = NULL) {
  if (is.null(label)) label <- sub("/$", "", sub("^https?://(www\\.)?", "", url))
  sprintf('#link("%s")[%s]', url, typst_esc(label))
}

# Year labels for the narrow left column, years only even when the data has
# months: "2021" + "" -> "since 2021"; "2018" + "2021" -> "2018\u20132021";
# equal years -> "2021".
years_label <- function(start, end) {
  s <- substr(start, 1, 4)
  e <- substr(end, 1, 4)
  dplyr::case_when(
    is.na(end) | end == "" ~ paste0("since ", s),
    e == s ~ s,
    TRUE ~ paste0(s, "\u2013", e)
  )
}

# Entries of one section, newest first (current rows on top).
section_rows <- function(section_id) {
  aboutme::entries |>
    filter(section == section_id) |>
    mutate(.end = ifelse(is.na(end) | end == "", "9999", end)) |>
    arrange(desc(.end), desc(start)) |>
    select(-.end)
}

# Emit a raw Typst block of #entry[years][body] lines. `body_fun` builds the
# body text from one row (already escaped where needed).
print_entries <- function(d, body_fun) {
  if (nrow(d) == 0) return(invisible())
  cat("\n```{=typst}\n")
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    cat(sprintf("#entry[%s][%s]\n", typst_esc(years_label(r$start, r$end)), body_fun(r)))
  }
  cat("```\n\n")
  invisible()
}

# Body builders -----------------------------------------------------------------

# Role in bold, organisation, place; description on request.
body_position <- function(r, describe = FALSE) {
  bits <- c(typst_esc(r$institution))
  if (!is.na(r$loc) && r$loc != "") bits <- c(bits, typst_esc(r$loc))
  out <- sprintf("*%s*, %s.", typst_esc(r$title), paste(bits, collapse = ", "))
  if (describe && !is.na(r$description_1) && r$description_1 != "")
    out <- paste(out, typst_esc(r$description_1))
  out
}

body_education <- function(r) {
  bits <- c(typst_esc(r$institution))
  if (!is.na(r$loc) && r$loc != "") bits <- c(bits, typst_esc(r$loc))
  sprintf("*%s*, %s.", typst_esc(r$title), paste(bits, collapse = ", "))
}

# Title and organisation, unless the title already names the organisation
# (the GFRN role does).
body_role <- function(r) {
  inst <- if (!is.na(r$institution) && r$institution != "" &&
              !str_detect(r$title, fixed(r$institution)))
    paste0(", ", typst_esc(r$institution)) else ""
  sprintf("*%s*%s.", typst_esc(r$title), inst)
}

# "acronym - long title" with the funder's call in brackets, one line each; the
# funder itself is named in the lead sentence above the list.
body_grant <- function(r) {
  parts <- str_split_fixed(r$title, " - ", 2)
  call <- if (str_detect(r$institution, "\\(")) {
    paste0(" (", sub(".*\\((.*)\\).*", "\\1", r$institution), ")")
  } else paste0(", ", r$institution)
  if (parts[2] != "") {
    sprintf("*%s*: %s%s.", typst_esc(parts[1]), typst_esc(parts[2]), typst_esc(call))
  } else sprintf("%s%s.", typst_esc(r$title), typst_esc(call))
}

body_teaching <- function(r) {
  bits <- c(typst_esc(r$institution))
  if (!is.na(r$loc) && r$loc != "") bits <- c(bits, typst_esc(r$loc))
  sprintf("*%s*, %s.", typst_esc(r$title), paste(bits, collapse = ", "))
}

# Publications ------------------------------------------------------------------

# "First Last and First Last" -> "Last, F., Last, F." with the own name in bold.
# The bib spells the surname Schoebitz and Schöbitz.
format_authors <- function(x, own = "Sch(o|ö)e?bitz") {
  parts <- str_split(x, " and ")[[1]]
  out <- vapply(parts, function(p) {
    w <- str_split(str_squish(p), " ")[[1]]
    sur <- w[length(w)]
    given <- w[-length(w)]
    name <- if (length(given)) {
      ini <- paste0(substr(given, 1, 1), ".", collapse = " ")
      paste0(sur, ", ", ini)
    } else sur
    if (str_detect(sur, own)) paste0("**", name, "**") else name
  }, character(1))
  paste(out, collapse = ", ")
}

# The bib carries a few LaTeX escapes in titles.
clean_tex <- function(x) {
  x |>
    str_replace_all(fixed("\\AA "), "Å") |>
    str_replace_all(fixed("\\\"o"), "ö") |>
    str_replace_all(fixed("``"), "“") |>
    str_replace_all(fixed("''"), "”")
}

# Rows of aboutme::publications of the given types, newest first. Empty outlets
# are filled from the DOI prefix (Gates Open Research) or from the matching
# conference_papers row in entries (WEDC conferences).
pubs <- function(types) {
  conf <- aboutme::entries |>
    filter(section == "conference_papers") |>
    transmute(year = as.integer(substr(start, 1, 4)), outlet_entries = institution,
              url_entries = url)
  aboutme::publications |>
    filter(type %in% types) |>
    mutate(year = as.integer(year),
           title = clean_tex(title),
           outlet = ifelse(is.na(outlet), "", outlet),
           doi = ifelse(is.na(doi), "", doi),
           url = ifelse(is.na(url), "", url)) |>
    left_join(conf, by = "year", relationship = "many-to-many") |>
    mutate(
      outlet = case_when(
        outlet != "" ~ outlet,
        str_detect(doi, "gatesopenres") ~ "Gates Open Research",
        type == "InProceedings" & !is.na(outlet_entries) ~ outlet_entries,
        TRUE ~ ""),
      url = ifelse(url == "" & !is.na(url_entries), url_entries, url),
      url = ifelse(is.na(url), "", url)) |>
    distinct(key, .keep_all = TRUE) |>
    arrange(desc(year), title)
}

# Markdown numbered list of publication rows (call with results='asis').
print_pubs <- function(d) {
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    outlet <- if (r$outlet != "") paste0(" *", r$outlet, "*.") else ""
    link <- if (r$doi != "") {
      sprintf(" [doi:%s](https://doi.org/%s)", r$doi, r$doi)
    } else if (r$url != "") {
      sprintf(" [%s](%s)", sub("^https?://(www\\.)?", "", r$url), r$url)
    } else ""
    cat(sprintf("%d. %s (%s). %s.%s%s\n", i, format_authors(r$author), r$year,
                r$title, outlet, link))
  }
  cat("\n")
  invisible()
}

# Markdown numbered list of entries rows (reports, data, software, courses).
# `institution` holds the publisher or the own role. A DOI found in the
# description columns wins over the url.
print_outputs <- function(d) {
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    desc <- paste(c(r$description_1, r$description_2, r$description_3), collapse = " ")
    doi <- str_extract(desc, "10\\.\\d{4,9}/[^\\s\"']+")
    link <- if (!is.na(doi)) {
      sprintf(" [doi:%s](https://doi.org/%s)", doi, doi)
    } else if (!is.na(r$url) && r$url != "") {
      sprintf(" [%s](%s)", sub("/$", "", sub("^https?://(www\\.)?", "", r$url)), r$url)
    } else ""
    who <- if (!is.na(r$institution) && r$institution != "") paste0(" ", r$institution, ".") else ""
    cat(sprintf("%d. %s. %s.%s%s\n", i, substr(r$start, 1, 4), r$title, who, link))
  }
  cat("\n")
  invisible()
}
