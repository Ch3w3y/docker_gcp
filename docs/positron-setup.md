# Setting Up Positron with WSL2 and Devcontainers

Positron is an IDE from Posit (the makers of RStudio) built on VS Code. It has
first-class support for both R and Python in the same window — a single console
per language, a variables explorer that works for both, and integrated plot
rendering. For bilingual pipeline work it is the recommended editor.

This guide covers two ways to use Positron with this project:

1. **WSL2 remote** — run Positron on Windows but edit files that live inside Linux
2. **Devcontainer** — run Positron inside the actual Docker container (recommended)

Complete [wsl-setup.md](./wsl-setup.md) before following this guide.

---

## A note for users coming from RStudio

If you have used RStudio for R work, Positron will feel familiar. Key differences:

- Positron handles Python and R in the same session without switching modes
- The console, environment, and plot panes work the same way as RStudio
- RStudio Projects (`.Rproj`) are not used here — the devcontainer replaces them
- R scripts still run with `Ctrl+Enter` (run selection) and `Ctrl+Shift+Enter`
  (run file), the same as RStudio
- The keyboard shortcut for the assignment operator (`<-`) is `Alt+-`, same as RStudio

If you are a Python user coming from VS Code, Positron is VS Code with the R
experience built in — the extension ecosystem and keyboard shortcuts are identical.

---

## Install Positron

Download the Windows installer from
[positron.posit.co](https://positron.posit.co) and run it. Positron installs
on Windows but connects to your Linux environment over WSL2.

---

## Install required extensions

Open Positron. Press `Ctrl+Shift+X` to open the Extensions panel. Install:

| Extension | Purpose |
|---|---|
| **Remote - WSL** (Microsoft) | Connects Positron to your WSL2 Ubuntu environment |
| **Dev Containers** (Microsoft) | Opens projects inside Docker containers |
| **GitLens** (GitKraken) | Enhanced git history and blame annotations |

The R and Python language support is built into Positron and does not require
separate extensions.

---

## Option 1: WSL2 Remote

This opens your project files from inside WSL2. Positron's terminal runs in
Linux, `git` uses the Linux git, and all paths are Linux paths. This is a
useful starting point and works without Docker running.

1. Open Positron
2. Press `Ctrl+Shift+P` to open the command palette
3. Type `WSL` and select **Remote-WSL: Connect to WSL**
4. Positron reconnects — the bottom-left status bar shows `[WSL: Ubuntu]`
5. Open your project: **File > Open Folder**, navigate to `~/projects/docker_gcp`

Your R and Python interpreters are now the ones installed in Ubuntu directly
(not the container). This is suitable for lightweight editing and running git
commands, but your pipeline environment (packages, Python version) will not
exactly match Cloud Run.

---

## Option 2: Devcontainer (recommended)

This opens your project inside the `gcp-etl` Docker container. The Python and
R interpreters, all packages, and the `/workspace` path all match what runs in
Cloud Run exactly. This is the recommended setup for day-to-day pipeline work.

### Requirements

- Docker Desktop must be running on Windows before you start
- You must be connected to WSL2 remote first (Option 1 above)

### First-time setup

1. Connect to WSL2 remote and open your project folder (Option 1 above)
2. Positron detects `.devcontainer/devcontainer.json` and shows a notification:
   **"Reopen in Container"** — click it

   If the notification does not appear:
   - Press `Ctrl+Shift+P`
   - Select **Dev Containers: Reopen in Container**

3. The first time, Docker pulls the `gcp-etl` image from GHCR. This is a
   several-hundred-megabyte download — it may take a few minutes on first run.
   Subsequent opens are instant.

4. Once connected, the status bar shows **Dev Container: gcp-pipeline**

### Verifying the environment

Open a terminal (`Ctrl+`` `) and confirm you are in the right environment:

```bash
# Python interpreter from the venv
which python          # expected: /opt/venv/bin/python
python --version      # expected: Python 3.12.x

# R from the system
which Rscript         # expected: /usr/bin/Rscript
Rscript --version     # expected: R scripting front-end version 4.5.x

# Confirm renv packages are available
Rscript -e "library(tidyverse); library(bigrquery); cat('OK\n')"

# Confirm Python GCP packages
python -c "from google.cloud import bigquery, storage; print('OK')"

# Confirm working directory
pwd                   # expected: /workspace
```

### Set up your environment variables

```bash
cp .env.example .env
```

Open `.env` in Positron and fill in your project-specific values. This file is
git-ignored and will never be committed.

---

## Running the pipeline inside the devcontainer

From the Positron terminal (you are already inside `/workspace`):

```bash
bash run.sh
```

To run only a specific script:

```bash
Rscript src/extract.R
python src/transform.py
```

To run tests:

```bash
# Python
pytest tests/ -v

# R
Rscript -e "testthat::test_dir('tests/testthat')"
```

---

## Debugging

### Python: interactive debugging

Positron supports VS Code's Python debugger. To debug a script:

1. Set a breakpoint by clicking in the gutter (left margin) next to a line number
2. Open the Run and Debug panel (`Ctrl+Shift+D`)
3. Click **Run and Debug** and select **Python File**

The execution pauses at your breakpoint. You can inspect variables, step through
code line by line, and evaluate expressions in the debug console.

### R: interactive debugging

Positron's R console supports `browser()` for interactive debugging:

```r
my_function <- function(df) {
  browser()  # execution pauses here
  df |> filter(value > 0)
}
```

When the function is called, R enters debug mode. Type `n` to step to the next
line, `c` to continue, `Q` to quit the debugger. The Variables pane shows all
objects in the current scope.

You can also use `traceback()` after an error to see the full call stack.

### Inspecting intermediate data

The Variables pane (right panel) shows all R and Python objects currently in
memory. Click on a data frame to open it in a table viewer. This is equivalent
to RStudio's Environment pane.

---

## Git workflow from Positron

The Source Control panel (`Ctrl+Shift+G`) provides a visual interface for
staging, committing, and managing branches. For analysts who prefer a visual
interface to the command line, this is the recommended way to commit changes.

For the command-line workflow, see [git-workflow.md](./git-workflow.md).

---

## Rebuilding the devcontainer

When the base image is updated (new packages added to `gcp-etl`), pull the
latest image and rebuild:

```bash
docker pull ghcr.io/ch3w3y/gcp-etl:latest
```

Then in Positron:
- Press `Ctrl+Shift+P`
- Select **Dev Containers: Rebuild Container**

Your project files are unaffected — they are bind-mounted from your WSL2
filesystem and persist across container rebuilds.

---

## Troubleshooting

**"Cannot connect to Docker daemon"**

Docker Desktop on Windows is not running. Start it from the Start menu and
wait for it to finish loading (the whale icon in the system tray stops animating).

**Devcontainer fails to start with an image pull error**

The base image may not yet be built and pushed to GHCR, or you are not
authenticated. Check that the `build-push.yml` workflow has run successfully
on the main branch of this repo. Until then, you can build locally:

- Edit `.devcontainer/devcontainer.json`
- Replace the `"image"` line with:
  ```json
  "build": { "context": "../gcp-etl", "dockerfile": "../gcp-etl/Dockerfile" }
  ```
- Save and reopen in container — Positron will build from the Dockerfile

**R packages not found inside the container**

The `renv.lock` restore may have failed during the image build. Check the image
build logs in GitHub Actions, or build locally and look for errors in the Docker
build output.

**`gcloud` not available inside the container**

The `gcloud` CLI is not installed in the container — it is not needed there.
Authentication to GCP inside the container happens via ADC, sourced from your
WSL2 credentials. If ADC is not working inside the container, make sure you
have run `gcloud auth application-default login` in your WSL2 terminal (outside
the container), and that the credentials file at
`~/.config/gcloud/application_default_credentials.json` exists. The devcontainer
mounts this directory automatically via the `workspaceMount` configuration.

> **Further reading**: [Positron documentation](https://positron.posit.co/docs/) | [Dev Containers specification](https://containers.dev/)
