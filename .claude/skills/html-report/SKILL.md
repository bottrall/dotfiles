---
name: html-report
description: HTML report generator. Use when the user asks for a report.
---

# HTML Report

Produce a single HTML report from whatever the context of this conversation is, save it to `~/reports`, and publish it as a Claude Artifact.

## Content

- Work from the current conversation: its subject, findings, data, and decisions are the report's content. If the subject is ambiguous, ask me what the report should cover before building it.
- Lead with a short summary, then supporting sections with detail.
- Use visualisations where they clarify things better than prose: tables for structured comparisons, bar/column charts for quantities, timelines for sequences, diagrams for relationships or flows.
- Keep visualisations simple and readable. A clean table beats a gimmicky chart.
- Use simple language.

## Implementation

- Publish the HTML file with the Artifact tool.
- Build charts as inline SVG, canvas, or plain HTML/CSS — whatever suits the data. Don't pull in a charting library unless the data genuinely needs one.
- Filename: `<YYYY-MM-DD>-<slug>.html` in `~/reports`, where slug is a few hyphenated words describing the subject. Create the directory if needed. If a file with that name already exists, add a `-2`/`-3` suffix rather than overwriting.
- Give me the artifact link.

## Updates

- When I ask for changes, edit the existing report's file and re-publish it to the same artifact. Only create a new file and artifact when I ask for a new report.
- If the report is from an earlier conversation, publish the update to its existing artifact URL. Find it with the Artifact tool's list, or ask me.
