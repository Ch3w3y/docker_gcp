---
name: docs-audit
description: Audit a docs/ page against the "R to the Cloud" style guide — checks plain language, admonition usage, Mermaid syntax, nav registration, and reading order links
---

Audit the specified `docs/` page (or the most recently edited file if not specified).

Read the file, then check each rule below. Report findings as a checklist.

## Rules

### 1. Plain language
- Every technical term (container, image, registry, IAM, ADC, renv, worktree,
  bind mount, GCS, ADC, workload identity) must be **defined on first use** or
  linked to an earlier page that defines it.
- Sentences should be short. Flag sentences over ~30 words.
- Passive voice should be rare — flag more than 2 instances per section.
- No assumed DevOps knowledge. Ask yourself: "Would a civil servant who has only
  used Excel and RStudio understand this?"

### 2. Admonitions
- Callouts must use `!!! tip`, `!!! warning`, `!!! important`, or `!!! note`.
- Flag any bold text (`**...**`) that is acting as a callout rather than emphasis.
- Each admonition block must have a blank line before its indented content.

### 3. Mermaid diagrams
- All fences must use `flowchart TD` or `flowchart LR` — NOT `graph TD` or
  `graph LR` (those don't work with the panzoom plugin).
- Node labels must use `<br/>` for line breaks — NOT `\n`.
- Node fill colours must have sufficient contrast for dark mode. Avoid `fill:#fff`
  or `fill:#f9f9f9` on light-coloured text.

### 4. Structure
- Page must have a `# Title` heading at the top.
- Should have a `## Overview` or similar intro section near the top.
- Should end with a `## Next steps` section or a cross-link to the next page in
  reading order (defined in `mkdocs.yml` nav).

### 5. Nav registration
- Check `mkdocs.yml` — the page filename must appear under the correct nav section.
- Flag if the nav title differs significantly from the `# Title` heading.

### 6. Build check
- Run `mkdocs build --strict --quiet` and include any errors in the report.

## Output format

Produce a checklist like:

```
## Audit: docs/example.md

- [x] Plain language: OK
- [ ] Admonitions: Line 47 uses bold text as a callout — replace with `!!! tip`
- [x] Mermaid: OK
- [ ] Structure: Missing "Next steps" section
- [x] Nav: Registered in mkdocs.yml under "Docker & Environments"
- [ ] Build: mkdocs build failed — see errors below
```

If everything passes, output: `All checks passed — page is ready.`
