---
name: design-slop
description: AI design slop tells in UI, landing pages, and mockups. Use when building or reviewing a visual design, or when a design reads as generated or templated.
---

# Design slop

Twenty tells mark a design as AI-generated. Each is a default reached for without a reason in the content. Treat every hit as a finding unless the brief or the content calls for it.

For positive design direction (typeface choice, layout, copy), see the `frontend-design` skill. This skill is the checklist.

## Use

- **Building:** check the plan against the table before writing markup, then check the rendered page again.
- **Reviewing:** check every row against the rendered page (a screenshot), as well as the code. Report each hit with its location and the replacement.

Done when every row is checked and each hit is fixed or justified by the content.

## Tells

| # | Tell | What it looks like | Instead |
|---|---|---|---|
| 1 | Tags and pills | Rows of rounded capsule labels under cards ("NAMING", "UX & STRUCTURE") | Plain text, or nothing. A pill only for a real filter, status, or input |
| 2 | Excessive italics | One word per headline in italic serif ("Be in the meeting. *Quill* takes the notes.") | One style per headline. Emphasis only where speech would stress the word |
| 3 | Instrument Serif | The Instrument Serif display face, often mixed with its italic | A face chosen for the subject |
| 4 | Negative kerning | Display type with tight negative letter-spacing, letters near touching | The face's default tracking. Tighten only what the face needs at that size |
| 5 | Over-the-top detailed UI | Mock dashboards packed with tiny numbers, charts, and badges | The one screen state the message needs, at a readable size |
| 6 | Overusing dividers | Hairline rules between every block | Separation by space and hierarchy. A rule only where groups need a hard edge |
| 7 | Color shades and opacities | One hue at many tints and alpha levels | A small fixed palette where each color has one role |
| 8 | Containers with borders | Every block inside a bordered box | Content on the page surface. A box only around a distinct object |
| 9 | Overly detailed diagrams | Architecture diagrams with many nodes, sublabels, and glowing outlines | Only the parts the reader needs. Labels the text already gives are cut |
| 10 | Verbose, redundant text | Paragraphs that restate the headline | One idea per element, said once |
| 11 | Code breadcrumbs | Code syntax as decoration: `// data products`, `<section>`, `$ install` | Normal headings and labels |
| 12 | Section numbering | 01 / 02 / 03 markers on content that is no sequence | Numbers only on a real sequence (steps, timeline) |
| 13 | Eyebrows | A small tracked-out label above each heading ("SPECIALTY COFFEE, EVERYDAY MAGIC") | The heading standing alone |
| 14 | Dithering | Dithered or halftone image treatments | Real imagery at full quality, or no image |
| 15 | ASCII images | ASCII-art globes, figures, and logos | Real imagery or illustration, or no image |
| 16 | Squircles | Superellipse corners on icons, cards, and buttons | Plain radii that follow the element's hierarchy |
| 17 | Excessive mono fonts | Monospace for labels, data, captions, and body text | Monospace for code only |
| 18 | ALL CAPS subtitles | Subtitles and labels set in capitals | Sentence case |
| 19 | Gradient backgrounds | Purple-blue gradient heroes and call-to-action panels | Flat color, or real imagery |
| 20 | Periods in titles | Headlines ending in a full stop ("A better kind of everyday.") | Headings with no terminal period |
