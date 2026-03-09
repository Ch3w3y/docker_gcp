# Design: Development Environment Introduction Pages

**Date:** 2026-03-09
**Status:** Approved
**Scope:** Two pages — one new, one expanded

---

## Problem

The guide currently jumps into tool setup without explaining what those tools are or why they form a coherent system. Readers familiar only with RStudio need answers to three questions before setup instructions mean anything:

1. What is an IDE, and what is the difference between R and RStudio?
2. Why switch from RStudio to Positron?
3. How do WSL2, Docker, Positron, and GCP fit together as a stack?

The existing `positron-setup.md` goes straight to install steps. `case-for-change.md` makes the case for Git/Docker/cloud but never grounds readers in the tools themselves.

---

## Solution

### Page 1: New — "Your Development Environment"

**File:** `docs/your-development-environment.md`
**Nav position:** First entry in the "Linux & WSL2" section (inserted before `what-is-linux.md`)
**Reading order step:** Inserted as new step 11, pushing existing steps 11–19 to 12–20

**Approach:** Narrative-first (C). Each new tool is introduced as the answer to a specific, concrete friction point the reader has just encountered — not as a concept to learn in the abstract.

**Tone:** Institutional, not personal. "RStudio is in daily use across the department" rather than "you open RStudio every morning."

**Narrative arc:**

1. **Anchor in the familiar** — RStudio is in daily use. It is a good tool. This section is not about replacing it arbitrarily.

2. **What is an IDE?** — One plain analogy: a mechanic's workshop. The tools (spanners, diagnostic computer) are arranged around the car. An IDE arranges your code editor, console, file browser, and debugger around your script. R is the engine; RStudio is one particular workshop layout for working on it.

3. **R vs RStudio** — R is the language. RStudio is one application that runs R. They are separate things: R would work from a plain text editor and a terminal. This distinction matters because the guide introduces a different application (Positron) that also runs R — and that only makes sense once readers understand the two are not the same thing.

4. **First friction point → WSL2** — RStudio on Windows and a cloud server running Linux are meaningfully different environments. File paths, line endings, available tools, and shell behaviour all differ. WSL2 is introduced as the answer: run Linux on your Windows laptop so local and cloud environments share the same foundation.

5. **Second friction point → Docker** — WSL2 closes the OS gap, but not the package gap. R version drift, package version drift, and undocumented system dependencies still cause "works on my machine" failures. Docker is introduced as the answer: lock the entire environment — OS layer, R version, every package — into a container that runs identically everywhere.

6. **Third friction point → Positron** — Once working with containers, analysts edit Dockerfiles, bash scripts, YAML, and Python alongside R. RStudio handles one language and one filetype well; it was not designed for this broader surface. Positron is introduced as the answer: a single editor with first-class support for R, Python, and all the surrounding file types, with built-in devcontainer integration so the editor opens inside the container.

7. **The stack lands** — By this point each tool has been introduced to solve a specific problem. A closing Mermaid diagram shows all five layers (R → Positron → WSL2 → Docker → GCP) with a one-line description of what each one solves.

8. **Longevity note** — Brief, honest, institutionally toned: Posit continues to support RStudio and has committed to doing so. Positron is where active development is concentrated. For teams adopting a cloud-native, polyglot workflow, Positron's VS Code foundation — mature extension ecosystem, remote development, devcontainers — is a better fit for where this work is going.

---

### Page 2: Expanded `positron-setup.md`

**Change:** New "Why Positron?" section inserted before the existing install steps.

**Contents:**

- **Feature comparison table** — RStudio vs Positron, covering: R support, Python support, file types, WSL2 remote, devcontainer integration, extension ecosystem, active development focus
- **Multi-filetype editing** — one short paragraph with concrete examples: Dockerfile, bash scripts, `cloud-run-job.yml`, and an R script open simultaneously in the same window with syntax highlighting and linting for each
- **Devcontainer integration** — one paragraph explaining the key benefit: the editor opens *inside* the container, so the R and Python interpreters, all packages, and the `/workspace` path all match Cloud Run exactly. This is not possible in RStudio without significant manual configuration.
- **Longevity note** — same framing as page 1 but with slightly more detail: Positron is built on VS Code's open-source core (Code - OSS), which means the remote development and devcontainer infrastructure is maintained by Microsoft, not just Posit.

---

## Nav changes

```yaml
# Before
- "Linux & WSL2":
    - "What Is Linux?": what-is-linux.md
    - "Setting Up WSL2": wsl-setup.md
    - "Positron IDE": positron-setup.md

# After
- "Linux & WSL2":
    - "Your Development Environment": your-development-environment.md
    - "What Is Linux?": what-is-linux.md
    - "Setting Up WSL2": wsl-setup.md
    - "Positron IDE": positron-setup.md
```

Reading order table in `index.md` updated to insert new step 11 and increment subsequent step numbers.

---

## Out of scope

- Changes to `case-for-change.md` — that page makes the case for the workflow, not the tools
- Changes to `wsl-setup.md` or `what-is-linux.md` — setup pages are unaffected
- Any pipeline code changes
