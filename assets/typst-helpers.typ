// Typst template for the full CV (cv-pdf.qmd), on the bitz brand. The rules
// mirror onepager/onepager.typ (the one-page CV), so both PDFs look alike;
// this file is inlined at the repo root, hence the brand path below.
#let brand = yaml("onepager/_brand.yml")
#let palette = brand.color.palette
#let token(name) = {
  let v = brand.color.at(name, default: name)
  rgb(palette.at(v, default: v))
}
#let primary = token("primary")
#let muted = token("secondary")
#let rule = token("grey-light")
#let bar = token("bitz-teal-light")

#set par(justify: false, leading: 0.5em, spacing: 0.6em)
#set list(spacing: 0.35em, indent: 0.6em)
#show link: set text(fill: primary)

#show heading.where(level: 1): it => block(above: 1.1em, below: 0.45em, width: 100%)[
  #text(size: 1em, weight: 700, fill: primary, tracking: 0.03em)[#upper(it.body)]
  #v(-0.55em)
  #line(length: 100%, stroke: 0.6pt + rule)
]
#show heading.where(level: 2): it => block(above: 0.8em, below: 0.35em)[
  #text(size: 1em, weight: 600, fill: primary)[#it.body]
]

#set page(footer: context [
  #set text(size: 7.5pt, fill: muted)
  Lars Schöbitz, curriculum vitae, #datetime.today().display("[month repr:long] [year]")
  #h(1fr)
  Page #counter(page).display() of #counter(page).final().first()
])

// Name, position line and the contact row at the top of page one.
#let name-block(name, role, contacts) = block(below: 0.8em, width: 100%)[
  #text(size: 19pt, weight: 700, fill: primary)[#name]
  #v(-0.35em)
  #text(size: 1.02em)[#role]
  #v(-0.3em)
  // Each contact sits in a box, so a long address or link never breaks inside;
  // the row wraps between items instead.
  #text(size: 0.9em, fill: muted)[#contacts.map(c => box(c)).join([ #h(0.45em) · #h(0.45em) ])]
  #v(0.15em)
  #line(length: 100%, stroke: 0.6pt + rule)
]

// One dated entry: the dates in the left column, the text in the right one.
// The column is wider than on the one-pager, since full dates appear here.
#let entry(dates, body) = block(below: 0.4em, width: 100%)[
  #grid(
    columns: (8em, 1fr),
    column-gutter: 0.7em,
    // Quarto's template justifies paragraphs; a wrapped date must not stretch.
    { set par(justify: false); text(size: 0.9em, fill: muted)[#dates] },
    body,
  )
]

// A labelled skill bar. `frac` in 0..1.
#let skill-bar(label, frac) = {
  block(spacing: 0.5em, width: 100%)[
    #text(size: 8.5pt)[#label]
    #v(-0.4em)
    #box(width: 100%, height: 5pt, radius: 1pt, fill: rule)[
      #box(width: frac * 100%, height: 5pt, radius: 1pt, fill: bar)
    ]
  ]
}

// Skills band under the intro: technical skills and languages side by side.
#let band(technical, languages) = {
  block(above: 0.6em, below: 0.6em, width: 100%)[
    #grid(
      columns: (1fr, 1fr),
      gutter: 2em,
      [
        #text(weight: 600, size: 9pt, fill: primary)[Technical skills] #v(0.2em)
        #technical
      ],
      [
        #text(weight: 600, size: 9pt, fill: primary)[Languages] #v(0.2em)
        #languages
      ],
    )
  ]
}
