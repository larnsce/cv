// Layout helpers for the one-page CV and the one-page publication list
// (cv-onepager.qmd). Colours and rules come from the brand file beside this
// document; nothing is hardcoded. Quarto's own template sets the base font and
// size from the same brand file.
#let brand = yaml("_brand.yml")
#let palette = brand.color.palette
#let token(name) = {
  let v = brand.color.at(name, default: name)
  rgb(palette.at(v, default: v))
}
#let primary = token("primary")
#let muted = token("secondary")
#let rule = token("grey-light")

#set par(justify: false, leading: 0.5em, spacing: 0.6em)
#set enum(spacing: 0.35em)
#show link: set text(fill: primary)

#show heading.where(level: 1): it => block(above: 0.95em, below: 0.4em, width: 100%)[
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

// One dated entry: years in the left column, the text in the right one.
#let entry(years, body) = block(below: 0.32em, width: 100%)[
  #grid(
    columns: (5.6em, 1fr),
    column-gutter: 0.7em,
    text(size: 0.9em, fill: muted)[#years],
    body,
  )
]
