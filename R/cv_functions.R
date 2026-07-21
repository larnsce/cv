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

  # Treat a literal "TODO" in a date field as "unknown", not as text.
  entries$start <- ifelse(entries$start == "TODO", NA, entries$start)
  entries$end   <- ifelse(entries$end   == "TODO", NA, entries$end)

  # Sort newest first by `end`, then `start`. A blank end means either "current"
  # (has a start) or "undated" (no start): current sorts to the top, undated to
  # the bottom, so unfinished TODO-dated rows don't jump ahead of real entries.
  yr <- function(x) suppressWarnings(as.integer(str_extract(as.character(x), "(19|20)\\d{2}")))
  entries <- entries |>
    mutate(
      .start = yr(start),
      .end = dplyr::case_when(
        !is.na(end) & end != "" ~ yr(end),
        !is.na(.start)          ~ 9999L,   # current
        TRUE                    ~ -1L       # undated -> bottom
      )
    ) |>
    arrange(desc(.end), desc(.start))

  tech_path <- file.path(data_dir, "technical_skills.csv")

  list(
    entries    = entries,
    skills     = rd("language_skills.csv"),
    tech_skills = if (file.exists(tech_path)) rd("technical_skills.csv") else NULL,
    text       = rd("text_blocks.csv"),
    contact    = rd("contact_info.csv")
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
    TRUE                ~ paste0(s, " - ", e)  # chronological: earlier - later
  )
}

#' Print one section of entries as markdown (call with results='asis').
#' @param style "block" = full entry with bullets (work, education, open data);
#'   "compact" = one dense line per entry (talks, teaching, workshops).
print_section <- function(cv, section_id, style = "block") {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (nrow(d) == 0) return(invisible())
  d$tl <- timeline(d$start, d$end)

  if (style == "compact") {
    lines <- character(nrow(d))
    for (i in seq_len(nrow(d))) {
      r <- d[i, ]
      ttl <- if (!is.na(r$url) && r$url != "") glue("[{r$title}]({r$url})") else r$title
      bits <- c()
      if (!is.na(r$institution) && r$institution != "") bits <- c(bits, r$institution)
      if (!is.na(r$loc) && r$loc != "") bits <- c(bits, r$loc)
      meta <- if (length(bits)) paste0(" ", paste(bits, collapse = ", ")) else ""
      dt <- if (!is.na(r$tl) && r$tl != "N/A") paste0("**", r$tl, "**  ") else ""
      lines[i] <- glue("{dt}{ttl}.{meta}")
    }
    # Emit as a markdown bullet list: one item per entry, blank line before/after.
    cat("\n")
    cat(paste0("- ", lines, collapse = "\n"))
    cat("\n\n")
    return(invisible())
  }

  # style == "block"
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

#' PDF-only: emit the full header band (contact | technical skills | languages)
#' as a single Typst #band(...) call. No-op for HTML output.
print_band <- function(cv, out_of = 5) {
  if (!isTRUE(knitr::pandoc_to("typst"))) return(invisible())

  contact <- paste(vapply(seq_len(nrow(cv$contact)), function(i) {
    r <- cv$contact[i, ]
    val <- gsub("\"", "'", r$contact)
    sprintf("#contact-line(\"%s\", \"%s\")", r$icon, val)
  }, character(1)), collapse = "\n")

  bars <- function(sk) paste(vapply(seq_len(nrow(sk)), function(i) {
    r <- sk[i, ]
    sprintf("#skill-bar(\"%s\", %s)", gsub("\"", "'", r$skill),
            round(as.numeric(r$level) / out_of, 3))
  }, character(1)), collapse = "\n")

  cat("```{=typst}\n")
  cat("#band(\n")
  cat("[", contact, "],\n")
  cat("[", bars(cv$tech_skills), "],\n")
  cat("[", bars(cv$skills), "],\n")
  cat(")\n")
  cat("```\n\n")
  invisible()
}

#' Print contact info with Font Awesome icons (HTML and Typst).
print_contact <- function(cv) {
  html <- !isTRUE(knitr::pandoc_to("typst"))
  if (html) {
    brands <- c("github", "linkedin", "orcid", "twitter")
    lines <- vapply(seq_len(nrow(cv$contact)), function(i) {
      r <- cv$contact[i, ]
      fam <- if (r$icon %in% brands) "fa-brands" else "fa-solid"
      glue("<i class='{fam} fa-{r$icon}'></i> {r$contact}")
    }, character(1))
    cat("\n")
    cat(paste0("- ", lines, collapse = "\n"))
    cat("\n\n")
  } else {
    cat("```{=typst}\n")
    for (i in seq_len(nrow(cv$contact))) {
      r <- cv$contact[i, ]
      val <- gsub("\"", "'", r$contact)
      cat(glue("#contact-line(\"{r$icon}\", \"{val}\")\n"), "\n")
    }
    cat("```\n\n")
  }
  invisible()
}

#' Print skill bars. `which` selects the table: "language" or "technical".
#' Emits CSS bars for HTML output and native Typst bars for PDF output.
print_skills <- function(cv, which = "language", out_of = 5) {
  skills <- if (which == "technical") cv$tech_skills else cv$skills
  if (is.null(skills) || nrow(skills) == 0) return(invisible())
  html <- !isTRUE(knitr::pandoc_to("typst"))

  if (html) {
    for (i in seq_len(nrow(skills))) {
      r <- skills[i, ]
      pct <- round(100 * as.numeric(r$level) / out_of)
      cat(glue(
        "<div class='skill-bar' style=\"background:linear-gradient(to right,",
        "#969696 {pct}%, #d9d9d9 {pct}% 100%)\">{r$skill}</div>\n"
      ))
    }
  } else {
    # Native Typst progress bars.
    cat("```{=typst}\n")
    for (i in seq_len(nrow(skills))) {
      r <- skills[i, ]
      frac <- round(as.numeric(r$level) / out_of, 3)
      lbl <- gsub("\"", "'", r$skill)
      cat(glue(
        "#skill-bar(\"{lbl}\", {frac})\n"
      ), "\n")
    }
    cat("```\n\n")
  }
  invisible()
}
