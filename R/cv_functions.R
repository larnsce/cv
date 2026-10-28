# cv_functions.R
# Read CV data from the aboutme data package and render sections as markdown
# or HTML. The package (github.com/larnsce/aboutme) is the canonical source;
# install it on the rendering machine before running ./render.sh.
#
# Dates: start and end are years (2021), year-months (2026-05) or full dates
# (2026-11-19). format_when() prints them at their own precision.
# Links: event_url is the website of the conference or event, url the
# materials (slides, repository, project page). The title links to the event
# site when there is one, else to the materials; a small second link follows
# when both exist. entry_links() holds that rule for every page.

suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
  library(stringr)
})

#' Load all CV data from the aboutme data package into a list.
create_cv <- function() {
  entries <- aboutme::entries
  # Older aboutme versions lack these columns; add them empty so the rest of
  # the code has one shape to work with.
  if (!"status" %in% names(entries)) entries$status <- NA_character_
  if (!"event_url" %in% names(entries)) entries$event_url <- NA_character_

  # Collapse description_1..N into a single bulleted block.
  desc_cols <- grep("^description", names(entries), value = TRUE)
  entries$bullets <- apply(entries[desc_cols], 1, function(r) {
    r <- r[!is.na(r) & r != ""]
    if (length(r) == 0) return("")
    paste0("- ", paste(r, collapse = "\n- "))
  })

  # Sort newest first by `end`, then `start`, on the date strings themselves
  # (2026-10-20 sorts after 2026-09 and 2026, so day, month and year rows
  # interleave by time). A blank end means either "current" (has a start) or
  # "undated" (no start): current sorts to the top, undated to the bottom.
  key <- function(x) ifelse(is.na(x) | x == "", "", as.character(x))
  entries <- entries |>
    mutate(
      .start = key(start),
      .end = dplyr::case_when(
        key(end) != ""   ~ key(end),
        .start != ""     ~ "9999",   # current
        TRUE             ~ ""        # undated -> bottom
      )
    ) |>
    arrange(desc(.end), desc(.start))

  list(
    entries      = entries,
    skills       = aboutme::language_skills,
    tech_skills  = aboutme::technical_skills,
    media        = aboutme::media,
    text         = aboutme::text_blocks,
    contact      = aboutme::contact_info,
    publications = aboutme::publications
  )
}

# ---- small helpers -----------------------------------------------------------

blank <- function(x) is.na(x) | as.character(x) == ""

#' Escape text for raw HTML output.
esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

#' Open and close a raw HTML block, so pandoc passes the markup through
#' unchanged (a bare <div> would be read as a native div and its contents
#' parsed as markdown, which breaks anchors that wrap block content).
raw_open  <- function() cat("\n```{=html}\n")
raw_close <- function() cat("```\n\n")

#' Markdown links to plain text, for text blocks reused inside raw HTML.
strip_md_links <- function(x) gsub("\\[([^]]+)\\]\\([^)]*\\)", "\\1", x)

#' First sentence of a text block.
first_sentence <- function(x) {
  x <- strip_md_links(trimws(x))
  s <- str_extract(x, "^.*?[.!?](\\s|$)")
  ifelse(is.na(s), x, trimws(s))
}

# ---- dates -----------------------------------------------------------------

#' One date at its own precision: "19 November 2026", "November 2026", "2026".
format_date_one <- function(x) {
  if (is.na(x) || x == "") return("")
  n <- nchar(x)
  y <- substr(x, 1, 4)
  if (n < 7) return(y)
  m <- month.name[as.integer(substr(x, 6, 7))]
  if (n < 10) return(paste(m, y))
  paste(as.integer(substr(x, 9, 10)), m, y)
}

format_when_one <- function(s, e) {
  if (s == "" && e == "") return("")
  if (s == "") return(format_date_one(e))
  if (e == "") return(paste("Since", format_date_one(s)))
  # A mixed pair (2026-11-19 to 2026-12) is shown at the coarser precision.
  p <- min(nchar(s), nchar(e))
  s <- substr(s, 1, p)
  e <- substr(e, 1, p)
  if (s == e) return(format_date_one(s))
  ys <- substr(s, 1, 4)
  ye <- substr(e, 1, 4)
  if (p < 7) return(paste(ys, "to", ye))
  ms <- month.name[as.integer(substr(s, 6, 7))]
  me <- month.name[as.integer(substr(e, 6, 7))]
  if (p < 10) {
    if (ys == ye) return(paste(ms, "to", me, ys))
    return(paste(ms, ys, "to", me, ye))
  }
  ds <- as.integer(substr(s, 9, 10))
  de <- as.integer(substr(e, 9, 10))
  if (ys == ye && ms == me) return(paste(ds, "to", de, ms, ys))
  if (ys == ye) return(paste(ds, ms, "to", de, me, ys))
  paste(ds, ms, ys, "to", de, me, ye)
}

#' Format start and end pairs as readable dates (vectorised).
#' "19 November 2026", "19 to 20 November 2026", "November 2026",
#' "October 2023 to February 2024", "2021 to 2023", "Since 2021", "".
format_when <- function(start, end) {
  s <- as.character(start)
  e <- as.character(end)
  s[is.na(s)] <- ""
  e[is.na(e)] <- ""
  if (length(s) == 0) return(character())
  mapply(format_when_one, s, e, USE.NAMES = FALSE)
}

#' Add .from and .to as Dates for event rows: day rows keep the day, month rows
#' span the month, year-only rows get NA (roles and courses that span years
#' are not events).
event_dates <- function(d) {
  to_date <- function(x, last = FALSE) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    out <- rep(as.Date(NA), length(x))
    day <- nchar(x) == 10
    mon <- nchar(x) == 7
    out[day] <- as.Date(x[day])
    if (any(mon)) {
      first <- as.Date(paste0(x[mon], "-01"))
      out[mon] <- if (last) as.Date(format(first + 31, "%Y-%m-01")) - 1 else first
    }
    out
  }
  d$.from <- to_date(d$start)
  d$.to   <- to_date(ifelse(blank(d$end), d$start, d$end), last = TRUE)
  d
}

#' Event rows of the given sections, upcoming (nearest first) or past (most
#' recent first), relative to `today`.
event_rows <- function(cv, sections, today = Sys.Date(), upcoming = TRUE,
                       limit = NULL) {
  d <- dplyr::filter(cv$entries, section %in% sections)
  d <- event_dates(d)
  d <- d[!is.na(d$.to), ]
  if (upcoming) {
    d <- d[d$.to >= today, ]
    d <- d[order(d$.from, d$.to), ]
  } else {
    d <- d[d$.to < today, ]
    d <- d[order(d$.to, d$.from, decreasing = TRUE), ]
  }
  if (!is.null(limit) && nrow(d) > limit) d <- utils::head(d, limit)
  d
}

# ---- links -----------------------------------------------------------------

#' Label for a materials link, from what the link points at.
link_label <- function(url) {
  u <- tolower(url)
  if (grepl("slides", u) || grepl("\\.html($|#)", u) || grepl("\\.pdf$", u)) return("slides")
  if (grepl("github\\.com", u)) return("repository")
  "materials"
}

#' Which link the title carries and which one follows it, for one row.
entry_links <- function(r) {
  ev <- r$event_url
  u  <- r$url
  has_ev <- !blank(ev)
  has_u  <- !blank(u)
  title_href <- if (has_ev) ev else if (has_u) u else NA_character_
  more_href  <- if (has_ev && has_u && ev != u) u else NA_character_
  list(
    title_href = title_href,
    more_href  = more_href,
    more_label = if (!is.na(more_href)) link_label(more_href) else NA_character_
  )
}

kind_label <- c(talks = "Talk", workshops = "Workshop", teaching = "Course")

# ---- grants ----------------------------------------------------------------

#' Grant status of each row: the `status` value, with a missing or blank status
#' read as "funded" (older aboutme versions, and grants entered before the
#' column existed).
grant_status <- function(status) {
  s <- tolower(trimws(as.character(status)))
  ifelse(is.na(s) | s == "", "funded", s)
}

#' Label shown in place of the dates for a grant proposal that was not
#' funded (yet): "Submitted 2026", "Not funded 2025".
proposal_label <- function(status, start) {
  lbl <- dplyr::case_when(
    status == "submitted"    ~ "Submitted",
    status == "unsuccessful" ~ "Not funded",
    TRUE                     ~ stringr::str_to_sentence(status)
  )
  yr <- ifelse(is.na(start) | start == "", "", paste0(" ", start))
  paste0(lbl, yr)
}

# ---- sections as markdown ----------------------------------------------------

#' Print one section of entries as markdown (call with results='asis').
#' @param style "block" = full entry with bullets (work, education, open data);
#'   "compact" = one dense line per entry (talks, teaching, workshops).
#' @param limit optional integer: keep only the first `limit` entries after
#'   sorting (used for "top N" summaries on the website CV page).
#' @param status optional character vector of grant statuses to keep
#'   ("funded", "submitted", "unsuccessful"); a missing status counts as
#'   "funded". NULL keeps all rows. Rows that are not funded show their status
#'   ("Submitted 2026", "Not funded 2025") in place of the dates, so a
#'   proposal never reads as current.
print_section <- function(cv, section_id, style = "block", limit = NULL,
                          status = NULL) {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (!is.null(status)) {
    keep <- tolower(status)
    d <- d[grant_status(d$status) %in% keep, ]
  }
  if (nrow(d) == 0) return(invisible())
  if (!is.null(limit) && nrow(d) > limit) d <- utils::head(d, limit)
  d$tl <- format_when(d$start, d$end)
  if (!is.null(status)) {
    st <- grant_status(d$status)
    pending <- st != "funded"
    d$tl[pending] <- proposal_label(st[pending], d$start[pending])
  }

  if (style == "compact") {
    lines <- character(nrow(d))
    for (i in seq_len(nrow(d))) {
      r <- d[i, ]
      lk <- entry_links(r)
      ttl <- if (!is.na(lk$title_href)) glue("[{r$title}]({lk$title_href})") else r$title
      bits <- c()
      if (!blank(r$institution)) bits <- c(bits, r$institution)
      if (!blank(r$loc)) bits <- c(bits, r$loc)
      meta <- if (length(bits)) paste0(" ", paste(bits, collapse = ", ")) else ""
      more <- if (!is.na(lk$more_href)) glue(" [{lk$more_label}]({lk$more_href})") else ""
      dt <- if (r$tl != "") paste0("**", r$tl, "**  ") else ""
      lines[i] <- glue("{dt}{ttl}.{meta}{more}")
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
    lk <- entry_links(r)
    ttl <- if (!is.na(lk$title_href)) glue("[{r$title}]({lk$title_href})") else r$title
    cat(glue("### {ttl}\n\n"))
    if (!blank(r$loc)) cat(r$loc, "\n\n")
    if (!blank(r$institution)) cat(r$institution, "\n\n")
    if (r$tl != "") cat(r$tl, "\n\n")
    if (!is.na(lk$more_href)) cat(glue("[{str_to_sentence(lk$more_label)}]({lk$more_href})"), "\n\n")
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

text_block <- function(cv, label) {
  t <- dplyr::filter(cv$text, loc == label)$text
  if (length(t)) t[[1]] else ""
}

# ---- start page -------------------------------------------------------------

#' The intro text block as the hero lead (a fenced div, so markdown inside the
#' block still renders).
print_lead <- function(cv, label = "intro") {
  cat("\n::: {.lse-lead}\n", text_block(cv, label), "\n:::\n\n", sep = "")
  invisible()
}

#' One line with the current positions: "Role, Institution. Role, Institution."
print_role_line <- function(cv) {
  d <- dplyr::filter(cv$entries, section == "work_experience", blank(end))
  if (nrow(d) == 0) return(invisible())
  parts <- paste0(esc(d$title), ", ", esc(d$institution))
  raw_open()
  cat("<p class=\"lse-role\">", paste0(parts, ".", collapse = " "), "</p>\n", sep = "")
  raw_close()
  invisible()
}

#' Contact details as one row of icon links.
print_contact_links <- function(cv, skip = "globe") {
  ci <- cv$contact
  ci <- ci[!ci$icon %in% skip, ]
  if (nrow(ci) == 0) return(invisible())
  brands <- c("github", "linkedin", "orcid", "twitter", "mastodon", "bluesky")
  links <- vapply(seq_len(nrow(ci)), function(i) {
    icon <- ci$icon[i]
    v <- ci$contact[i]
    href <- switch(icon,
      envelope = paste0("mailto:", v),
      orcid    = paste0("https://orcid.org/", v),
      globe    = v,
      paste0("https://", sub("^https?://", "", v))
    )
    fam <- if (icon %in% brands) "fa-brands" else "fa-solid"
    label <- if (icon == "orcid") paste("ORCID", v) else v
    sprintf("<a href=\"%s\"><i class=\"%s fa-%s\"></i>%s</a>", esc(href), fam, icon, esc(label))
  }, character(1))
  raw_open()
  cat("<p class=\"lse-contact\">", paste(links, collapse = "\n"), "</p>\n", sep = "")
  raw_close()
  invisible()
}

#' Live counts from the data: years in WASH, talks and workshops given,
#' courses taught, publications.
print_numbers <- function(cv, today = Sys.Date()) {
  e <- cv$entries
  work <- dplyr::filter(e, section == "work_experience")
  first_year <- suppressWarnings(min(as.integer(substr(work$start, 1, 4)), na.rm = TRUE))
  years <- as.integer(format(today, "%Y")) - first_year
  n_events <- sum(e$section %in% c("talks", "workshops")) -
    nrow(event_rows(cv, c("talks", "workshops"), today, upcoming = TRUE))
  n_courses <- sum(e$section == "teaching")
  n_pubs <- nrow(cv$publications)
  items <- list(
    c(years, "years in WASH"),
    c(n_events, "talks and workshops"),
    c(n_courses, "courses taught"),
    c(n_pubs, "publications")
  )
  raw_open()
  cat("<div class=\"lse-numbers\">\n")
  for (it in items) {
    cat(sprintf("<div class=\"lse-number-item\"><div class=\"lse-number\">%s</div><div class=\"lse-number-label\">%s</div></div>\n",
                it[1], it[2]))
  }
  cat("</div>\n")
  raw_close()
  invisible()
}

#' Cards for event rows (from event_rows()): date kicker, title linking to the
#' event site, kind plus venue and place, a second link to the materials.
print_event_cards <- function(d, class = "lse-cards", fence = TRUE) {
  if (nrow(d) == 0) return(invisible())
  if (fence) raw_open()
  cat("<div class=\"", class, "\">\n", sep = "")
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    lk <- entry_links(r)
    when <- format_when(r$start, r$end)
    ttl <- if (!is.na(lk$title_href))
      sprintf("<a href=\"%s\">%s</a>", esc(lk$title_href), esc(r$title)) else esc(r$title)
    kind <- if (r$section %in% names(kind_label)) kind_label[[r$section]] else "Event"
    bits <- c()
    if (!blank(r$institution)) bits <- c(bits, r$institution)
    if (!blank(r$loc)) bits <- c(bits, r$loc)
    meta <- paste0(kind, if (length(bits)) paste0(". ", paste(bits, collapse = ", ")) else "")
    more <- if (!is.na(lk$more_href))
      sprintf("\n<a class=\"lse-card-more\" href=\"%s\">%s</a>",
              esc(lk$more_href), str_to_sentence(lk$more_label)) else ""
    cat(sprintf("<div class=\"lse-card\">\n<span class=\"lse-card-kicker\">%s</span>\n<strong>%s</strong>\n<p class=\"lse-card-meta\">%s</p>%s\n</div>\n",
                esc(when), ttl, esc(meta), more))
  }
  cat("</div>\n")
  if (fence) raw_close()
  invisible()
}

#' The whole Upcoming section (heading and cards), or nothing when no talk,
#' workshop or course is ahead, so no empty heading appears.
print_upcoming_cards <- function(cv, sections = c("talks", "workshops", "teaching"),
                                 today = Sys.Date()) {
  d <- event_rows(cv, sections, today, upcoming = TRUE)
  if (nrow(d) == 0) return(invisible())
  raw_open()
  cat("<div class=\"lse-section\">\n<h2>Upcoming</h2>\n")
  print_event_cards(d, fence = FALSE)
  cat("</div>\n")
  raw_close()
  invisible()
}

#' The most recent past talks and workshops as cards.
print_recent_cards <- function(cv, sections = c("talks", "workshops"), limit = 3,
                               today = Sys.Date()) {
  d <- event_rows(cv, sections, today, upcoming = FALSE, limit = limit)
  print_event_cards(d)
}

#' The newest rows of a section as date-then-title rows (used for the blog).
print_latest_rows <- function(cv, section_id = "blog", limit = 3) {
  d <- dplyr::filter(cv$entries, section == section_id)
  if (nrow(d) == 0) return(invisible())
  if (nrow(d) > limit) d <- utils::head(d, limit)
  raw_open()
  cat("<div class=\"lse-rows\">\n")
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    lk <- entry_links(r)
    tag <- if (!is.na(lk$title_href)) sprintf("<a class=\"lse-row\" href=\"%s\">", esc(lk$title_href)) else "<div class=\"lse-row\">"
    close <- if (!is.na(lk$title_href)) "</a>" else "</div>"
    meta <- if (!blank(r$institution)) sprintf("<span class=\"lse-row-meta\">%s</span>", esc(r$institution)) else ""
    cat(sprintf("%s<span class=\"lse-row-date\">%s</span><span class=\"lse-row-title\">%s</span>%s%s\n",
                tag, esc(format_when(r$start, r$end)), esc(r$title), meta, close))
  }
  cat("</div>\n")
  raw_close()
  invisible()
}

#' Cards that point to the other pages, each with the first sentence of the
#' page's intro text block.
print_explore_cards <- function(cv) {
  cards <- list(
    list("Research", "research.html", "research_intro"),
    list("Software and data", "software.html", "software_intro"),
    list("Teaching", "teaching.html", "teaching_intro"),
    list("Media", "media.html", "media_intro"),
    list("CV", "cv.html", "cv_intro")
  )
  raw_open()
  cat("<div class=\"lse-cards lse-cards-explore\">\n")
  for (cd in cards) {
    cat(sprintf("<a class=\"lse-card\" href=\"%s\"><strong>%s</strong><p>%s</p></a>\n",
                cd[[2]], esc(cd[[1]]), esc(first_sentence(text_block(cv, cd[[3]])))))
  }
  cat("</div>\n")
  raw_close()
  invisible()
}

# ---- PDF and other pages -----------------------------------------------------

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
#' results='asis'). Reads the media table (outlet, date, kind, title, url).
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
