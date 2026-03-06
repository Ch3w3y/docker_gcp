# Design: Documentation Refinement and Restructure

**Date:** 2026-03-06
**Branch strategy:** One branch → PR → merge per page (Option B)
**Trigger:** `deploy-docs.yml` runs on every merge, publishing incrementally to GitHub Pages

---

## Problem statement

The guide is content-rich and well-written but has two structural issues:

1. **Wrong reading order.** "From Notebooks to Pipelines" content (modular code, functions, packages, tests) is buried after Docker — readers arrive at Git without knowing how to write code worth versioning.
2. **Diagram and formatting rough edges.** Several flowcharts have cramped multi-sentence node labels, duplicated concept tables across pages, and an ASCII art diagram that should be a proper `gitGraph`.

---

## New reading order (19 steps)

| Step | Page | Status |
|:----:|------|--------|
| 1 | The Case for Modern Workflows | unchanged |
| 2 | **Organising Your R Code** | moved up + expanded |
| 3 | **Writing Functions** | **new page** |
| 4 | **Building R Packages** | moved up + expanded |
| 5 | **Writing Tests** | moved up + expanded |
| 6 | From Shared Drives to Git | unchanged |
| 7 | What Is Version Control? | refined |
| 8 | The GitHub Workflow | refined |
| 9 | Making Code GitHub-Ready | unchanged |
| 10 | Sanitising Code for GitHub | unchanged |
| 11 | What Is Linux? | unchanged |
| 12 | Setting Up WSL2 | unchanged |
| 13 | Containers Explained | refined |
| 14 | Managing R & Python Versions | unchanged |
| 15 | Generating and Sharing Outputs | unchanged |
| 16 | AMR Surveillance Pipeline | unchanged |
| 17 | How the Pipeline Works | unchanged |
| 18 | GitHub Actions Explained | refined |
| 19 | GCP Deployment | unchanged |

---

## Page-by-page changes

### Step 2 — `code-organisation.md` (expand)

**New content:**
- **Sourcing mental model**: `source("transform.R")` is identical in execution to having that code inline — the interpreter sees the same thing. The benefit is purely human: named files, independent modules, easier navigation. Use a side-by-side code block showing monolith vs sourced equivalent.
- **Progression narrative**: one long script → named sections with comments → separate files with `source()` → full package structure (forward pointer to step 4).
- **Modularity and Git** *(new closing section)*: when two analysts edit `extract.R` and `transform.R` respectively, Git merges them with zero conflict. When both edit a 500-line monolith, conflict is almost certain. Include a `gitGraph` diagram showing parallel branch work on separate modules.

### Step 3 — `writing-functions.md` (new page)

**Content from scratch:**
- **Opening analogy**: an RMarkdown chunk is a function waiting to be named. Show a labelled chunk being extracted into a named function, step by step, with identical output.
- **RMarkdown → R scripts**: RMarkdown is a fine development scratchpad — running chunks interactively is a natural way to explore and plan. But for deployment, chunks become functions in `.R` files. The transition is mechanical: name the chunk's inputs (arguments) and outputs (return value).
- **When to write a function**: used more than once, or needs a name for clarity. Rule of thumb: if you find yourself copying a block of code, write a function.
- **Pure functions**: same inputs → same outputs, no side effects. Why this matters for pipelines: predictable, testable, safe to run repeatedly.
- **Argument design**: named arguments, sensible defaults, fail loud on bad input (`stop()` / `stopifnot()`).
- **Modularity + Git connection**: each function in its own named file means colleagues can work on different functions simultaneously without merge conflicts (reinforces step 2).

### Step 4 — `r-packages.md` (expand)

**New content:**
- **`usethis` workflow**: `usethis::create_package()`, `usethis::use_r("transform")`, `usethis::use_testthat()`, `usethis::use_github_actions()`.
- **roxygen2 full example**: complete documented function showing `@title`, `@description`, `@param`, `@return`, `@export`, `@examples`. Show `devtools::document()` generating the `.Rd` file.
- **`devtools` development loop**: `devtools::load_all()` → edit → `devtools::document()` → `devtools::check()`. Explain why `load_all()` is faster than `source()` for package development.

### Step 5 — `testing-guide.md` (expand)

**New content:**
- **What makes a good unit test for a pipeline function**: deterministic (no randomness), no external calls (no BigQuery, no GCS), tests one behaviour per `test_that()` block.
- **testthat patterns**: `expect_equal()`, `expect_error()`, `expect_warning()`, `expect_true()`, `expect_snapshot()`. Show each with a realistic pipeline example.
- **Fixtures**: `setup.R` with `make_test_isolates()` style helpers — create synthetic data once, reuse across test files.
- **GitHub Actions connection**: show that `testthat::test_dir('tests/testthat')` in CI is *identical* to the command run locally. The workflow file is just a machine that runs the same command you run by hand.

### Step 7 — `git-fundamentals.md` (refine)

**Diagram fixes:**
- Fetch-merge-push flowchart: rewrite all node labels to single short phrases (currently multi-sentence). Example: `"Start: checkout main, git pull Get the latest from GitHub"` → `"Sync: git checkout main && git pull"`.
- State diagram: move the explanatory note out of the diagram into surrounding prose.

### Step 8 — `git-workflow.md` (refine)

**Changes:**
- Remove the "Core concepts" table (it duplicates `git-fundamentals.md`; replace with a single cross-link sentence).
- Replace ASCII art timeline with a `gitGraph` diagram.
- Add a brief intro sentence linking back to the modularity/Git point from step 2 (why separate files mean the PR diff is smaller and easier to review).

### Step 13 — `docker-containers.md` (refine)

**Diagram fixes:**
- VM vs containers: simplify into two side-by-side columns rather than a tall vertical stack.
- "What lives inside vs outside": split into two separate, smaller diagrams — one for the image contents, one for the runtime injection (env vars + volume mount).

### Step 18 — `github-actions.md` (refine)

**New content:**
- Add a summary diagram *before* the per-workflow detail showing all three workflows (`test.yml`, `build-push.yml`, `deploy-docs.yml`), their triggers, and their outcomes in one view.

### `index.md` + `mkdocs.yml` (final PR)

- Update reading order table to 19-step structure.
- Update `mkdocs.yml` nav to match new order.
- Update forward/back cross-links on affected pages.

---

## Delivery order (branch per page)

```
feat/expand-code-organisation    → PR → merge
feat/new-writing-functions       → PR → merge
feat/expand-r-packages           → PR → merge
feat/expand-testing-guide        → PR → merge
feat/refine-git-fundamentals     → PR → merge
feat/refine-git-workflow         → PR → merge
feat/refine-docker-containers    → PR → merge
feat/refine-github-actions       → PR → merge
feat/reorder-index               → PR → merge  ← final
```

Each merge triggers `deploy-docs.yml` (publishes to GitHub Pages) and `test.yml` (runs testthat + pytest on the example pipeline), providing a per-feature audit trail.

---

## Success criteria

- New reading order is live on GitHub Pages with all 19 steps correctly linked.
- `writing-functions.md` exists and is reachable from `index.md`.
- All expanded pages (`code-organisation`, `r-packages`, `testing-guide`) cover their new topics with working code examples.
- No flowchart node contains more than one sentence.
- `git-workflow.md` contains no duplicated concept table.
- All diagrams render correctly in MkDocs Material.
- CI passes on every merge.
