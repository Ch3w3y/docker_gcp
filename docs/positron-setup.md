# Setting Up Positron with WSL2 and Devcontainers

Positron is an IDE from Posit (the makers of RStudio) built on VS Code. It has
first-class support for both R and Python, making it well suited for bilingual
pipelines. This guide covers two ways to use it with this project:

1. **WSL2 remote** — edit files inside WSL2 from Positron running on Windows
2. **Devcontainer** — edit files inside the actual pipeline container

For most day-to-day work, the devcontainer option gives you the closest match
to the cloud environment and is recommended.

---

## Prerequisites

- WSL2 and Ubuntu installed (see [wsl-setup.md](./wsl-setup.md))
- Docker Desktop running with WSL2 integration enabled
- Your project cloned inside WSL2 (`~/projects/docker_gcp`)

---

## Install Positron

Download Positron from [positron.posit.co](https://positron.posit.co) and
install it on Windows. It runs on Windows but connects to your Linux environment
over WSL2.

---

## Option 1: WSL2 Remote

This opens your project files from inside WSL2. Positron's terminal runs in
Linux, `git` uses the Linux git, and paths are Linux paths. This is a good
starting point before setting up a devcontainer.

1. Open Positron on Windows
2. Press `Ctrl+Shift+P` to open the command palette
3. Type `WSL` and select **Remote-WSL: Connect to WSL**
4. Positron reconnects with a `[WSL: Ubuntu]` label in the bottom-left corner
5. Open your project: **File > Open Folder** and navigate to `~/projects/docker_gcp`

You now have a Linux terminal in Positron. Your R and Python interpreters are
the ones installed in Ubuntu (not the container yet).

---

## Option 2: Devcontainer (recommended)

This opens your project inside the `gcp-etl` Docker container. The Python and R
interpreters, all packages, and the `/workspace` path all match what runs in
Cloud Run exactly.

### First-time setup

1. Connect to WSL2 remote first (Option 1 above)
2. Open the project folder in Positron
3. Positron should detect the `.devcontainer/devcontainer.json` file and show a
   notification: **"Reopen in Container"** — click it

   If the notification does not appear:
   - Press `Ctrl+Shift+P`
   - Type `Dev Containers` and select **Dev Containers: Reopen in Container**

4. The container builds the first time (this takes a few minutes — it is
   installing all the R and Python packages from the Dockerfile)
5. Once connected, the bottom-left corner shows **Dev Container: gcp-pipeline**

### Verifying the environment

Open a terminal in Positron (`Ctrl+`` `) and check:

```bash
# Should show /opt/venv/bin/python
which python

# Should show Python 3.12.x
python --version

# Should show /usr/bin/Rscript
which Rscript

# Should show 4.5.x
Rscript --version

# Should list your renv packages
Rscript -e "rownames(installed.packages(lib.loc='/renv/library'))"
```

### Running the pipeline locally

From the Positron terminal (inside the container):

```bash
cd /workspace
bash run.sh
```

Or use `docker compose` from your WSL2 terminal (outside the container) if you
prefer to keep the container lifecycle separate from your editor.

---

## Working with .env files

Create your local environment file from the example:

```bash
cp .env.example .env
```

Edit `.env` with your project values. This file is git-ignored and will never
be committed. When you run the pipeline locally (via `docker compose` or
directly inside the devcontainer), these values are loaded automatically.

---

## Committing and pushing from Positron

The Git panel in Positron works normally when connected to WSL2 or a devcontainer.
Branch protection rules on the remote repo mean you cannot push directly to `main`.
The expected workflow is:

1. Create a new branch for your change
2. Commit your changes
3. Push the branch
4. Open a pull request on GitHub
5. Tests run automatically, then a reviewer approves the merge

```bash
# In the Positron terminal
git checkout -b your-branch-name
git add src/transform.py tests/test_pipeline.py
git commit -m "your change description"
git push -u origin your-branch-name
```

---

## Rebuilding the devcontainer

If the base image is updated (new packages added), rebuild your local container:

- Press `Ctrl+Shift+P`
- Select **Dev Containers: Rebuild Container**

This pulls the latest image and restarts the container. Your project files are
unaffected as they are bind-mounted from your WSL2 filesystem.
