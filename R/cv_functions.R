# cv_functions.R
# Read CV data from the aboutme data package and render sections as markdown.
# The package (github.com/larnsce/aboutme) is the canonical source; install it
# on the rendering machine before running ./render.sh.

suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
  library(stringr)
})

#' Load all CV data from the aboutme data package into a list.
create_cv <- function() {
  entries <- aboutme::entries

  # Collapse description_1..N into a single bulleted block.
  desc_cols <- grep("^description", names(entries), value = TRUE)
  entries$bullets <- apply(entries[desc_cols], 1, function(r) {
    r <- r[!is.na(r) & r != ""]
    if (length(r) == 0) return("")
    paste0("- ", paste(r, collapse = "\n- "))
  })

  # Sort newest first by `end`, then `start`. A blank end means either "current"
  # (has a start) or "undated" (no start): current sorts to the top, undated to
  # the bottom.
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

  list(
    entries     = entries,
    skills      = aboutme::language_skills,
    tech_skills = aboutme::technical_skills,
    media       = aboutme::media,
    text        = aboutme::text_blocks,
    contact     = aboutme::contact_info
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
#' @param limit optional integer: keep only the first `limit` entries after
#'   sorting (used for "top N" summaries on the website CV page).
print_section <- function(cv, section_id, style = "block", limit = NULL) {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (nrow(d) == 0) return(invisible())
  if (!is.null(limit) && nrow(d) > limit) d <- utils::head(d, limit)
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

#' Print a publication-style list as an HTML <ul class="pub-list"> (call with
#' results='asis'). Reads title, `institution` (used as the journal/venue slot),
#' the year from `start`, `url` (rendered as a [DOI] link), and the optional
#' `status` column (rendered as a coloured pub-tag). Newest first.
#'
#' @param cv the list from create_cv().
#' @param section_id which entries.csv section to render.
#' @param type optional character vector: keep only rows whose `type` is in this
#'   set (e.g. "article", "report"). NULL keeps all rows in the section.
#' @param numbered if TRUE, prefix each item with a bold reverse index.
#' @param limit optional integer: keep only the first `limit` entries.
#' @param link_label label for the url link (default "DOI").
print_pub_list <- function(cv, section_id, type = NULL, numbered = FALSE,
                           limit = NULL, link_label = "DOI") {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (!is.null(type) && "type" %in% names(d)) {
    keep <- type
    d <- dplyr::filter(d, !is.na(.data$type) & .data$type %in% keep)
  }
  if (nrow(d) == 0) return(invisible())
  if (!is.null(limit) && nrow(d) > limit) d <- utils::head(d, limit)

  status_tag <- function(s) {
    if (is.na(s) || s == "") return("")
    cls <- if (grepl("review", s, ignore.case = TRUE)) "tag-review" else "tag-wip"
    sprintf(" <span class=\"pub-tag %s\">%s</span>", cls, s)
  }

  n <- nrow(d)
  cat("\n<ul class=\"pub-list\">\n")
  for (i in seq_len(n)) {
    r <- d[i, ]
    yr    <- if (!is.na(r$start) && r$start != "") sprintf(" (%s)", r$start) else ""
    venue <- if (!is.na(r$institution) && r$institution != "")
      sprintf(" *%s*.", r$institution) else ""
    link  <- if (!is.na(r$url) && r$url != "")
      sprintf(" [%s](%s)", link_label, r$url) else ""
    num   <- if (numbered) sprintf("**%d.** ", n - i + 1) else ""
    tag   <- if ("status" %in% names(r)) status_tag(r$status) else ""
    cat(sprintf("<li>%s%s%s%s%s%s</li>\n",
                num, r$title, yr, venue, link, tag))
  }
  cat("</ul>\n\n")
  invisible()
}

#' Print media coverage as an HTML <ul class="media-list"> (call with
#' results='asis'). Reads data/media.csv (outlet, date, kind, title, url).
#'
#' @param cv the list from create_cv().
#' @param kind optional character vector to filter by `kind`
#'   (press, radio, podcast, video, tv). NULL keeps all rows.
print_media <- function(cv, kind = NULL) {
  m <- cv$media
  if (is.null(m) || nrow(m) == 0) return(invisible())
  if (!is.null(kind)) {
    keep <- kind
    m <- dplyr::filter(m, .data$kind %in% keep)
  }
  if (nrow(m) == 0) return(invisible())
  # Newest first by date string (YYYY or YYYY-MM sort lexically as intended).
  m <- m[order(as.character(m$date), decreasing = TRUE), ]

  cat("\n<ul class=\"media-list\">\n")
  for (i in seq_len(nrow(m))) {
    r <- m[i, ]
    title <- if (!is.na(r$url) && r$url != "")
      sprintf("[%s](%s)", r$title, r$url) else r$title
    date  <- if (!is.na(r$date) && r$date != "")
      sprintf("<span class=\"media-date\">%s</span>", r$date) else ""
    cat(sprintf("<li><span class=\"media-outlet\">%s</span>%s<br>%s</li>\n",
                r$outlet, date, title))
  }
  cat("</ul>\n\n")
  invisible()
}

#' Print the upcoming talks and workshops as a callout box (call with
#' results='asis'). Keeps the rows of the talks and workshops sections whose
#' last month (end, or start when end is blank) is the current month or later;
#' start and end carry month precision (YYYY-MM). Nearest event first, so the
#' next date sits on top. Emits nothing when no row is upcoming, which hides
#' the box.
#'
#' @param cv the list from create_cv().
#' @param sections the entries sections that count as events.
#' @param today the reference date (a Date); default Sys.Date().
#' @param title the callout title.
print_upcoming <- function(cv, sections = c("talks", "workshops"),
                           today = Sys.Date(),
                           title = "Upcoming talks and workshops") {
  d <- dplyr::filter(cv$entries, section %in% sections)
  if (nrow(d) == 0) return(invisible())

  month_key <- function(x) {
    x <- as.character(x)
    ifelse(is.na(x) | x == "", NA_character_, substr(x, 1, 7))
  }
  d$.from <- month_key(d$start)
  d$.to   <- dplyr::coalesce(month_key(d$end), d$.from)
  this_month <- format(today, "%Y-%m")
  d <- d[!is.na(d$.to) & d$.to >= this_month, ]
  if (nrow(d) == 0) return(invisible())
  d <- d[order(d$.from, d$.to), ]

  month_label <- function(ym) {
    ok <- !is.na(ym) & grepl("^\\d{4}-\\d{2}$", ym)
    out <- ym
    out[ok] <- format(as.Date(paste0(ym[ok], "-01")), "%B %Y")
    out
  }
  kind <- c(talks = "Talk", workshops = "Workshop")

  lines <- character(nrow(d))
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    when <- if (identical(r$.from, r$.to)) month_label(r$.from)
            else paste(month_label(r$.from), "to", month_label(r$.to))
    label <- if (r$section %in% names(kind)) kind[[r$section]] else "Event"
    ttl <- if (!is.na(r$url) && r$url != "") glue("[{r$title}]({r$url})") else r$title
    bits <- c()
    if (!is.na(r$institution) && r$institution != "") bits <- c(bits, r$institution)
    if (!is.na(r$loc) && r$loc != "") bits <- c(bits, r$loc)
    meta <- if (length(bits)) paste0(" ", paste(bits, collapse = ", ")) else ""
    lines[i] <- glue(
      "**{when}** <span class=\"pub-tag tag-wip\">{label}</span> {ttl}.{meta}"
    )
  }

  cat("\n::: {.callout-note .upcoming-box title=\"", title,
      "\" appearance=\"simple\" icon=false}\n\n", sep = "")
  cat(paste0("- ", lines, collapse = "\n"))
  cat("\n\n:::\n\n")
  invisible()
}
