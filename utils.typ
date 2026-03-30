#import "@preview/fontawesome:0.6.0": *
#import "@preview/touying:0.6.3": *
#import themes.metropolis: *

/// #mail
///
/// - email (str): the email address of the author
/// -> (block): a block containing the email address
#let mail(email) = {
  show raw: set text(size: 0.8em)
  text(size: 1.2em)[#raw(email)]
}

/// 
/// - name (str): the name of the author
/// -> (block): a block containing the name of the author
#let first_author(name) = {
  strong(name)
}

/// #author_list
///
/// - authors (list of tuples): a list of tuples containing names and emails
/// -> (block): a block containing the authors' information
#let author_list(authors, logo: none, width: 35%) = block[
  #table(
    inset: (0em, 0em), column-gutter: 1em, row-gutter: 0.75em, stroke: none, columns: (auto, 4fr), align: (left, left),
    ..authors.map((record) => (record.at(0), mail(record.at(1)))).flatten()
  )
  #if logo != none {
    place(right)[
      #figure(image(logo, width: width))
    ]
  }
  #v(1em)
]

/// #bold
///
/// - content (block): the content to be displayed in bold
/// -> (block): a block containing the bolded content
#let bold(content) = {
  text(weight: "bold")[#content]
}

#let styled-block(
  title, 
  content, 
  icon: none, 
  fill-color: white,
  stroke-color: rgb("#23373b").lighten(55%),
  header-fill-color: rgb("#23373b").lighten(88%),
  accent-color: rgb("#eb811b"),
  title-color: rgb("#23373b"),
  content-color: rgb("#23373b").darken(10%),
  title-size: 1.02em,
) = {
  block(
    width: 100%,
    inset: 0em,
    fill: fill-color,
    radius: 0.45em,
    stroke: (
      paint: stroke-color, 
      thickness: 0.04em,
      dash: "solid"
    ),
    clip: true,
    [
      #block(width: 100%, height: 0.1em, fill: stroke-color)[]
      #block(
        width: 100%,
        inset: (x: 0.72em, top: 0.5em, bottom: 0.5em),
        fill: header-fill-color,
      )[
        #grid(
          columns: if icon != none { (auto, 1fr) } else { (1fr,) },
          column-gutter: 0.38em,
          align: left + horizon,
          if icon != none {
            box(
              fill: accent-color.lighten(82%),
              text(weight: "bold", size: 0.8em, fill: accent-color)[#icon],
            )
          },
          block[
            #text(weight: "bold", size: title-size, fill: title-color)[#title]
          ],
        )
      ]
      #block(
        width: 100%,
        inset: (x: 0.72em, bottom: 0.8em),
      )[
        #set text(fill: content-color)
        #content
      ]
    ]
  )
}

/// Blocks
#let feature-block(title, content) = {
  styled-block(
    title, 
    content,
    fill-color: white,
    stroke-color: rgb("#23373b").lighten(65%),
    header-fill-color: rgb("#23373b").lighten(92%),
    accent-color: rgb("#eb811b"),
  )
}

#let note-block(title, content, icon: fa-info-circle() + " ") = {
  styled-block(
    title, 
    content, 
    icon: icon,
    fill-color: rgb("#fffdf6"),
    stroke-color: rgb("#f2d995"),
    header-fill-color: rgb("#fff7d6"),
    accent-color: rgb("#c69214"),
    title-color: rgb("#8a6100"),
  )
}

#let warning-block(title, content, icon: fa-exclamation-triangle() + " ") = {
  styled-block(
    title, 
    content, 
    icon: icon,
    fill-color: rgb("#fff7f0"),
    stroke-color: rgb("#f0ba7d"),
    header-fill-color: rgb("#ffe4c7"),
    accent-color: rgb("#e66a00"),
    title-color: rgb("#e65100"),
  )
}

#let placeholder-figure(
  title,
  caption: none,
  height: 5.8cm,
  fill-color: rgb("#f5f5f5"),
  stroke-color: rgb("#b0bec5"),
) = figure(
  placement: none,
  caption: caption,
  block(
    width: 100%,
    height: height,
    inset: 18pt,
    radius: 10pt,
    fill: fill-color,
    stroke: (paint: stroke-color, thickness: 1.5pt, dash: "dashed"),
    align(center + horizon)[
      #text(size: 1.4em, weight: "bold", fill: rgb("#546e7a"))[#title]
      #v(0.4em)
      #text(size: 0.9em, fill: rgb("#607d8b"))[Placeholder image]
    ],
  ),
)
