// Typst helpers for the CV PDF: Font Awesome contact lines and skill bars.
// Included via the `include-in-header` key of the typst format in cv.qmd.
#import "@preview/fontawesome:0.5.0": *

// Map contact_info.csv icon names to Font Awesome symbols.
#let icon-for(name) = {
  let m = (
    envelope: fa-envelope(),
    globe: fa-globe(),
    github: fa-github(),
    orcid: fa-orcid(),
    linkedin: fa-linkedin(),
    twitter: fa-twitter(),
    location-dot: fa-location-dot(),
    phone: fa-phone(),
  )
  m.at(name, default: fa-circle())
}

// One contact line: icon + value, tight spacing, small type.
#let contact-line(icon, value) = {
  block(spacing: 0.45em)[
    #text(size: 8pt)[#icon-for(icon)~~#value]
  ]
}

// A labelled skill bar. `frac` in 0..1.
#let skill-bar(label, frac) = {
  block(spacing: 0.5em, width: 100%)[
    #text(size: 8pt)[#label]
    #v(-0.4em)
    #box(width: 100%, height: 5pt, radius: 1pt, fill: rgb("#d9d9d9"))[
      #box(width: frac * 100%, height: 5pt, radius: 1pt, fill: rgb("#5a5a5a"))
    ]
  ]
}

// Top band: three side-by-side columns (contact, technical skills, languages).
// Used only in the PDF to keep the header compact instead of stacking.
#let band(contact, technical, languages) = {
  block(above: 0.6em, below: 1em, width: 100%)[
    #grid(
      columns: (1.1fr, 1fr, 0.9fr),
      gutter: 1.2em,
      [
        #text(weight: "bold", size: 9pt)[Contact] #v(0.2em)
        #contact
      ],
      [
        #text(weight: "bold", size: 9pt)[Technical Skills] #v(0.2em)
        #technical
      ],
      [
        #text(weight: "bold", size: 9pt)[Languages] #v(0.2em)
        #languages
      ],
    )
    #line(length: 100%, stroke: 0.5pt + rgb("#cccccc"))
  ]
}
