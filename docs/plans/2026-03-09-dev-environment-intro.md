# Development Environment Introduction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a narrative-first "Your Development Environment" page and expand `positron-setup.md` with a "Why Positron?" section, so readers understand the full tool stack before any setup begins.

**Architecture:** One new page inserted as step 11 in the reading order (narrative arc: RStudio → friction points → each tool introduced as the solution → full stack diagram). One expanded section prepended to the existing `positron-setup.md`. Two nav/index updates to wire everything together.

**Tech Stack:** MkDocs Material, Mermaid diagrams, Markdown admonitions. No pipeline code changes.

---

### Task 1: Create `your-development-environment.md`

**Files:**
- Create: `docs/your-development-environment.md`

**Step 1: Create the file with the full narrative content**

```markdown
# Your Development Environment

RStudio is in daily use across the department. It is a capable, well-supported tool for R analysis — and nothing in this guide changes that. But as analytical work moves toward version-controlled code, reproducible environments, and cloud-based pipelines, a set of questions tends to arise:

- Why are we being asked to install Linux on a Windows laptop?
- What does a container have to do with running R?
- What is Positron, and why not just keep using RStudio?

This page answers those questions in order, starting from what you already know.

---

## What is an IDE?

RStudio is an **IDE** — an Integrated Development Environment. The term sounds technical but the concept is simple: an IDE is a workshop. The workbench has a place for your code (the editor), a place to run it (the console), a place to see your variables (the environment pane), and a place to see your plots. Everything a developer needs is arranged in one window.

The key thing to understand about an IDE is what it is *not*: it is not the programming language. R and RStudio are two separate things.

---

## R and RStudio are not the same thing

**R** is the programming language — the engine. It is a piece of software that reads R code and executes it. It runs entirely from a command line and has no interface of its own.

**RStudio** is one application for working with R — the dashboard. It makes R more accessible by wrapping it in a visual interface, but R itself does not know or care whether RStudio is involved.

This distinction matters because the rest of this guide introduces a different application for working with R — one that is better suited to the kind of work cloud-based analytical pipelines require. R continues to be the language throughout. The workshop changes.

---

## The first friction point: your laptop runs Windows, the cloud runs Linux

RStudio on Windows works well for writing and running R code locally. The problem appears when that code needs to run in the cloud.

Cloud servers — including the Google Cloud Run jobs this guide builds toward — run **Linux**, not Windows. Linux and Windows are different operating systems. File paths look different (`/workspace/data` vs `C:\Users\name\data`). The available command-line tools differ. Behaviour that works on one can silently fail on the other.

The traditional solution — "test locally on Windows, deploy to Linux and hope it works" — is the source of a large proportion of pipeline failures that are difficult to diagnose.

```mermaid
flowchart LR
    W["Windows laptop\n(RStudio)"]
    G["Google Cloud Run\n(Linux)"]
    W -- "deploy" --> G
    W -.->|"different OS\ndifferent paths\ndifferent tools"| G

    style G fill:#06b6d4,stroke:#0891b2,color:#ffffff
    style W fill:#475569,stroke:#1e293b,color:#ffffff
```

**WSL2 closes this gap.** WSL2 (Windows Subsystem for Linux) runs a real Linux environment directly inside Windows. When you develop inside WSL2, your file paths, your shell, and your tools all behave identically to the cloud server. The OS gap disappears.

---

## The second friction point: packages drift, environments diverge

Closing the OS gap does not close the environment gap.

Analytical pipelines depend on specific versions of R packages. `dplyr 1.1.0` and `dplyr 1.0.0` behave differently. When a colleague's machine has a different version — or when a package is updated automatically — results can change without any code changing. Over time, team members' environments drift apart, and a script that works for one person fails for another.

This is the **reproducibility problem**: the environment a script runs in is as important as the script itself, but traditional tools do not capture or enforce it.

```mermaid
flowchart TD
    A["Analyst A\nR 4.3, dplyr 1.1.0\nScript runs ✓"]
    B["Analyst B\nR 4.2, dplyr 1.0.0\nScript fails ✗"]
    C["Cloud Run\nR 4.5, dplyr 1.1.4\nScript produces different results ✗"]

    style B fill:#9b1c1c,stroke:#7f1d1d,color:#ffffff
    style C fill:#92400e,stroke:#78350f,color:#ffffff
    style A fill:#475569,stroke:#1e293b,color:#ffffff
```

**Docker closes this gap.** A Docker container packages the exact environment a pipeline needs — the Linux version, the R version, every R and Python package down to the patch release — into a single, reproducible unit. That container runs identically on any machine and on Cloud Run. There is no "works on my machine" because every machine runs the same container.

---

## The third friction point: analytical work is no longer just R files

When pipelines are simple R scripts, RStudio is sufficient. But a cloud-based pipeline involves more than R:

- A `Dockerfile` that defines the container environment
- A `run.sh` bash script that orchestrates the pipeline steps
- A `cloud-run-job.yml` YAML file that defines the Cloud Run Job
- Python scripts for data engineering tasks
- Configuration files, test files, CI workflow files

RStudio was built for R. It opens R files well. For everything else — Dockerfiles, bash, YAML, Python — it offers little help: no syntax highlighting, no linting, no language-aware completion.

**Positron closes this gap.** Positron is an IDE built by Posit (the makers of RStudio) on the VS Code platform. It has first-class support for R and Python in the same window, and handles every other file type in a cloud pipeline with the full VS Code extension ecosystem behind it. More importantly, Positron has built-in support for *devcontainers* — a feature that lets the editor open inside the Docker container, so the environment you develop in is identical to the environment that runs in Cloud Run.

---

## The stack, assembled

Each tool in this guide was introduced above as the solution to a specific problem. Assembled together, they form a coherent development stack:

```mermaid
flowchart TD
    R["R — the language\nWriting analytical logic"]
    P["Positron — the IDE\nEditing R, Python, Dockerfiles,\nbash, YAML in one window"]
    W["WSL2 — the OS layer\nRunning Linux on Windows\nso local matches cloud"]
    D["Docker — the environment\nLocking R version, packages,\nand dependencies reproducibly"]
    G["GCP Cloud Run — the platform\nRunning containers on a schedule\nin the cloud, automatically"]

    R --> P --> W --> D --> G

    style R fill:#475569,stroke:#1e293b,color:#ffffff
    style P fill:#475569,stroke:#1e293b,color:#ffffff
    style W fill:#475569,stroke:#1e293b,color:#ffffff
    style D fill:#475569,stroke:#1e293b,color:#ffffff
    style G fill:#06b6d4,stroke:#0891b2,color:#ffffff
```

| Layer | What it solves |
|---|---|
| **R** | The language the team already knows |
| **Positron** | A single editor for the full range of file types in a cloud pipeline |
| **WSL2** | OS parity between Windows development and Linux production |
| **Docker** | Environment reproducibility — same packages, same R version, everywhere |
| **GCP Cloud Run** | Automated, scheduled execution without infrastructure to manage |

The rest of this guide works through each layer in turn, starting with the Linux foundation that everything else builds on.

---

## A note on RStudio and Positron

Posit continues to support and develop RStudio. For teams doing pure R analysis work — no cloud deployment, no containers, no Python — it remains a strong choice and there is no pressing reason to change.

For teams moving toward cloud-based, reproducible pipelines — which is what this guide is about — Positron is the better fit. It is built on the same VS Code foundation used by the devcontainer and remote development tooling this guide relies on, and it is where Posit is concentrating new development for the kind of bilingual, cloud-connected analytical work this guide describes. The investment in learning Positron is an investment in a platform with a large, maintained ecosystem behind it.

!!! tip "Continue the guide"
    Next: [What Is Linux?](what-is-linux.md) — the operating system that underpins WSL2, Docker, and Cloud Run.
```

**Step 2: Verify the file renders**

```bash
cd /home/daryn/docker_gcp
mkdocs build 2>&1 | grep -E "ERROR|built in"
```

Expected: `INFO - Documentation built in X.XX seconds` with no ERROR lines.

**Step 3: Commit**

```bash
git add docs/your-development-environment.md
git commit -m "docs: add Your Development Environment narrative intro page"
```

---

### Task 2: Expand `positron-setup.md` with "Why Positron?" section

**Files:**
- Modify: `docs/positron-setup.md` (prepend new section before "A note for users coming from RStudio")

**Step 1: Insert the new section**

Insert the following block at line 9 of `positron-setup.md`, immediately after the opening admonition and before the existing introductory paragraph:

```markdown
## Why Positron?

If RStudio is already installed and working, it is reasonable to ask why this guide recommends switching. The short answer is that Positron is better suited to the kind of work a cloud-based analytical pipeline involves. The longer answer is in the table below.

| Capability | RStudio | Positron |
|---|---|---|
| R support | ✓ First-class | ✓ First-class |
| Python support | Partial (reticulate) | ✓ First-class, separate console |
| Dockerfile editing | Plain text only | ✓ Syntax highlighting, linting |
| Bash script editing | Plain text only | ✓ Syntax highlighting |
| YAML editing | Plain text only | ✓ Schema-aware completion |
| WSL2 remote development | Limited | ✓ Built-in (Remote - WSL extension) |
| Devcontainer support | Not supported | ✓ Built-in (Dev Containers extension) |
| Extension ecosystem | R-focused | VS Code ecosystem (thousands of extensions) |
| Active development focus | Maintenance mode | ✓ Primary development target at Posit |

### Editing a pipeline in practice

A cloud pipeline project contains R files, Python files, a `Dockerfile`, a `run.sh` bash script, `cloud-run-job.yml`, and GitHub Actions YAML files. In Positron, all of these open with full language support — syntax highlighting, linting, and completion — in the same window. In RStudio, the non-R files open as plain text with no tooling.

### Devcontainer integration

The most significant capability difference for cloud pipeline work is devcontainer support. When Positron opens a project inside a devcontainer, the editor's R and Python interpreters, the installed packages, and the `/workspace` path all come from inside the Docker container — the same environment that runs in Cloud Run. There is no gap between what runs locally and what runs in production.

This is not possible with RStudio without substantial manual configuration.

### Longevity

Posit continues to support RStudio and has made commitments to ongoing development. For teams doing pure R analysis work, RStudio remains appropriate.

Positron is built on Code - OSS (the open-source core of VS Code), which means the remote development and devcontainer infrastructure it relies on is maintained by Microsoft, independently of Posit. For teams adopting cloud-native workflows, this foundation is well-established and widely used beyond the R community. Positron is where Posit is concentrating new feature development for bilingual, cloud-connected analytical work.

---
```

**Step 2: Verify the file renders**

```bash
mkdocs build 2>&1 | grep -E "ERROR|built in"
```

Expected: clean build, no errors.

**Step 3: Commit**

```bash
git add docs/positron-setup.md
git commit -m "docs: add Why Positron? section to positron-setup"
```

---

### Task 3: Update `mkdocs.yml` nav

**Files:**
- Modify: `mkdocs.yml`

**Step 1: Insert new page into nav**

Find the `"Linux & WSL2":` section and add the new page as the first entry:

```yaml
  - "Linux & WSL2":
    - "Your Development Environment": your-development-environment.md
    - "What Is Linux?": what-is-linux.md
    - "Setting Up WSL2": wsl-setup.md
    - "Positron IDE": positron-setup.md
```

**Step 2: Verify build**

```bash
mkdocs build 2>&1 | grep -E "ERROR|WARNING(?!.*2\.0)|built in"
```

Expected: clean build.

**Step 3: Commit**

```bash
git add mkdocs.yml
git commit -m "docs(nav): insert Your Development Environment as step 11"
```

---

### Task 4: Update `index.md` reading order table

**Files:**
- Modify: `docs/index.md`

**Step 1: Insert new row and renumber**

Find the reading order table. Insert a new row at step 11 and increment all subsequent step numbers by 1 (11→12 through 19→20):

```markdown
| 11 | [Your Development Environment](your-development-environment.md) | What an IDE is, R vs RStudio, why Positron, and how WSL2 + Docker + GCP fit together |
| 12 | [What Is Linux?](what-is-linux.md) | Linux and WSL2 explained with plain analogies |
| 13 | [Setting Up WSL2](wsl-setup.md) | Step-by-step environment setup on Windows |
| 14 | [Positron IDE](positron-setup.md) | Installing Positron, WSL2 remote, and devcontainer setup |
| 15 | [Containers Explained](docker-containers.md) | What Docker is and why it solves the reproducibility problem |
| 16 | [Managing R & Python Versions](version-management.md) | Locking dependencies with `renv` and `requirements.txt` |
| 17 | [Generating and Sharing Outputs](outputs-and-reporting.md) | ggplot2 reports to GCS, public URLs, scheduled outputs |
| 18 | [AMR Surveillance Pipeline](example-walkthrough.md) | See every concept applied to a complete, runnable R pipeline |
| 19 | [How the Pipeline Works](architecture.md) | The full cloud architecture — commit to production |
| 20 | [GitHub Actions Explained](github-actions.md) | CI/CD demystified: how automated tests and deployments work |
| 21 | [GCP Deployment](gcp-deployment.md) | Deploying to Cloud Run (platform team guide) |
```

Also update the learning journey diagram in `index.md` — the `F` node currently says `15–19. Cloud Deployment`, update to `16–21. Cloud Deployment`.

**Step 2: Verify build**

```bash
mkdocs build 2>&1 | grep -E "ERROR|built in"
```

**Step 3: Commit**

```bash
git add docs/index.md
git commit -m "docs(index): add step 11 Your Development Environment, renumber to 21 steps"
```

---

### Task 5: Push and verify

**Step 1: Push to remote**

```bash
git push origin main
```

**Step 2: Serve locally and manually verify**

```bash
mkdocs serve
```

Open `http://127.0.0.1:8000` and check:
- New "Your Development Environment" page appears in nav under "Linux & WSL2"
- Narrative flows correctly — friction points lead naturally to each tool
- Stack diagram renders correctly
- `positron-setup.md` shows "Why Positron?" before the install steps
- Reading order table in `index.md` has 21 steps, no duplicate numbers

**Step 3: Done**
