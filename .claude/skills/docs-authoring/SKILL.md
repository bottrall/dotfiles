---
name: docs-authoring
description: Write documentation for libraries and packages
---

# Docs

Write clear, concise documentation for a library or package.

## Steps

### 1. Understand the subject

- Read the source code, existing README, changelog, and any existing documentation.
- Identify the library's purpose in one sentence. **If you cannot state it in one sentence, keep reading until you can.**
- List the public API surface: exported functions, classes, methods, types, configuration options.
- Run the test suite or read the tests to understand expected behavior and edge cases.
- **If the library has no tests:** note this limitation and rely on source code analysis and inline comments.

### 2. Identify the audience

- Determine who will read this documentation. Ask me if unclear. Common audiences:
  - **End users** integrating the library into their project.
  - **Contributors** who will modify or extend the library.
  - **Operators** who deploy or configure it.
- **Default to end users** unless I specify otherwise.
- Note the audience's likely skill level and what they already know. Never explain concepts the audience is expected to understand (e.g., do not explain what a function is to a developer audience).

### 3. Determine the documentation type

Decide which type of documentation fits the request. Each type has a different goal — do not mix them in a single document:

- **Tutorial:** walks a beginner through a complete working example. Learning-oriented. Ends with something the reader built.
- **How-to guide:** steps to accomplish a specific task. Assumes the reader already knows the basics. No teaching.
- **Reference:** complete, accurate description of every part of the API. No narrative, no opinions. Tables and signatures.
- **Explanation:** discusses why things work the way they do. Architecture decisions, trade-offs, design rationale.

**If I ask for a README:** combine a brief tutorial (quick start) with a reference summary. Keep the tutorial under 20 lines of code.

**If I don't specify a type:** ask me what the reader needs to accomplish, then pick the type that fits.

### 4. Outline before writing

- Draft a flat list of sections (no more than two levels of headings).
- Order sections by what the reader needs first. Lead with the most common use case, not the most general concept.
- **Every section must earn its place.** If a section restates information from another section, cut it. If a section covers an edge case that affects less than 10% of users, move it to the end or omit it.
- Show me the outline and get confirmation before writing the full document. **Do not skip this step.**

### 5. Write the documentation

Follow these rules strictly:

**Voice and tone:**

- Use second person ("you") throughout.
- Use active voice. Never write "the function is called" — write "call the function."
- Be prescriptive. Recommend one way to do things. Do not list alternatives unless the choice genuinely depends on the reader's situation.
- Write in plain language. If a simpler word exists, use it.

**Structure:**

- One idea per sentence. One topic per paragraph.
- Keep sentences to 15–20 words on average. Break long sentences.
- Start sections with what the reader will do or learn, not with background.
- Use bullet points for lists of 3 or more items. Use numbered lists only for sequential steps.
- Use ASCII diagrams to explain data flow, architecture, or relationships between components. Prefer diagrams over paragraphs of description.

**Code examples:**

- **Every code example must be complete and copy-pasteable.** No `...` or `// rest of code here`. The reader must be able to run it without modification.
- Show the simplest possible example first, then add complexity.
- Include the import/require statement in every example. Never assume the reader knows where to import from.
- **Add expected output as a comment** after any expression that produces a result.
- Use realistic variable names and data. No `foo`, `bar`, `baz`, `myVar`, or `example123`.

**Progressive disclosure:**

- Start with the 80% use case. Cover advanced usage and configuration after the basics.
- Put warnings and caveats near the code they affect, not in a separate "gotchas" section.

### 6. Validate the output

- **No duplication:** search the document for repeated information. If two sections say the same thing, keep it in one place and remove or link from the other.
- **No dead ends:** every concept mentioned must be either explained in the document or linked to an external resource. Do not reference something without giving the reader a way to learn about it.
- **Examples work:** re-read every code example against the source code. Verify function names, argument order, return types, and default values are accurate.
- **Consistent terminology:** pick one term for each concept and use it everywhere. Do not alternate between synonyms (e.g., "options" and "config" and "settings" for the same thing).
- **Heading scan test:** read only the headings in order. They should tell a coherent story of what the reader will learn and do. If a heading is vague (e.g., "Advanced"), make it specific (e.g., "Custom middleware for request logging").

### 7. Done

Print the complete documentation. If it's a new file, suggest where it should live in the project. If it updates an existing file, show the full replacement content.
