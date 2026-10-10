---
name: html-report
description: Generate a standalone HTML report summarising the current conversation's context or work, with visualisations where appropriate, saved into ~/reports and opened in the browser. Use when the user asks for a report, a summary document, or to 'report on' / 'visualise' what was discussed or built.
---

# HTML Report

Produce a single self-contained HTML report from whatever the context of this conversation is, save it to `~/reports`, and open it in the browser.

## Content

- Work from the current conversation: its subject, findings, data, and decisions are the report's content. If the subject is ambiguous, ask me what the report should cover before building it.
- Lead with a short summary, then supporting sections with detail.
- Use visualisations where they clarify things better than prose: tables for structured comparisons, bar/column charts for quantities, timelines for sequences, diagrams for relationships or flows.
- Keep visualisations simple and readable. A clean table beats a gimmicky chart.
- Use simple language.

## Implementation

- One self-contained HTML file: inline all CSS and JavaScript, no external dependencies, no network requests. It must render correctly offline and when moved or emailed.
- Build charts as inline SVG, canvas, or plain HTML/CSS — whatever suits the data. Don't pull in a charting library unless the data genuinely needs one.
- Filename: `<slug>-<YYYY-MM-DD>.html` in `~/reports`, where slug is a few hyphenated words describing the subject. Create the directory if needed. If a file with that name already exists, add a `-2`/`-3` suffix rather than overwriting.
- Open it with the platform opener. e.g. `open <path>` on macOS, `xdg-open <path>` on Linux.
