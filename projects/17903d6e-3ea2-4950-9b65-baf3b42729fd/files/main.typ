#import "lib.typ": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()



#set text(
  lang: "it",
)

// show chapter on figure numbering
#set figure(numbering: (..num) => numbering("1.1", counter(heading).get().first(), num.pos().first()))

// show chapter on equation numbering
#set math.equation(numbering: (..num) => numbering("(1.1)", counter(heading).get().first(), num.pos().first()))

#set heading(numbering: "1.1")

// only apply numbering up to h3
#show heading: it => {
  if (it.level > 3) {
    block(it.body)
  } else {
    block(counter(heading).display() + " " + it.body)
  }
}

// only apply numbering to figures with captions
#show figure: it => {
  if it.caption != none {
    numbering("Figure 1")
  }
  it
}

#show heading.where(level: 1): set text(size: 22pt)
#show heading.where(level: 2): set text(size: 17pt)
#show heading.where(level: 3): set text(size: 14pt)
#show heading.where(level: 4): set text(size: 14pt)
#show heading.where(level: 5): set text(size: 12pt)

#show: ilm.with(
  title: [Advanced Data Management],
  author: "Federico Segala",
  imagePath: "images/unilogo.png",
  abstract: [
    Anno Accademico: 2025-2026#linebreak()
    Appunti del corso di Advanced Data Management #linebreak()
    prof. Claudio Silvestri
  ],
  figure-index: (enabled: true),
  table-index: (enabled: true),
  listing-index: (enabled: true),
)



#include "chapters/chapter1.typ"
#include "chapters/chapter2.typ"
#include "chapters/chapter3.typ"



