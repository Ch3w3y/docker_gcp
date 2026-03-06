# Setting Up WSL2 on Windows 11 Enterprise

This guide walks through getting a Linux development environment running on a
Windows 11 Enterprise laptop. This is required to run Docker containers locally
and to use the devcontainer setup that mirrors our cloud environment.

---

## Before you start: contact IT

Windows 11 Enterprise restricts some features by default. You will need IT to
enable and install the following before proceeding:

| What to ask for | Why |
|---|---|
| WSL2 (Windows Subsystem for Linux 2) | Runs a real Linux kernel on Windows |
| Docker Desktop (with WSL2 backend) | Runs containers locally |
| Windows Terminal | Better terminal experience than Command Prompt |

When contacting IT, quote: **"WSL2 with Ubuntu distribution and Docker Desktop
with WSL2 backend integration enabled."**

---

## Step 1: Verify WSL2 and Ubuntu are installed

Once IT has completed the setup, open **Windows Terminal** (search for it in
the Start menu) and run:

```powershell
wsl --list --verbose
```

You should see something like:

```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

The `VERSION` column must show `2`. If it shows `1`, contact IT.

---

## Step 2: Open an Ubuntu terminal

In Windows Terminal, click the dropdown arrow next to the `+` tab button and
select **Ubuntu**. You are now inside Linux.

First-time setup — create your Linux user when prompted, then run:

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

---

## Step 3: Install the Google Cloud CLI

The Google Cloud CLI (`gcloud`) lets you authenticate to GCP from your terminal.

```bash
# Add the Google Cloud SDK package source
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
  https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

sudo apt-get update && sudo apt-get install -y google-cloud-cli
```

Verify the install:

```bash
gcloud --version
```

---

## Step 4: Authenticate to GCP

```bash
gcloud auth login
```

This opens a browser window. Sign in with your work Google account.

Then set up Application Default Credentials (ADC), which R and Python GCP
libraries use automatically:

```bash
gcloud auth application-default login
```

Sign in again when prompted. You only need to do this once per machine.

Set your default project:

```bash
gcloud config set project YOUR_PROJECT_ID
```

---

## Step 5: Verify Docker is connected to WSL2

In your Ubuntu terminal:

```bash
docker --version
docker run --rm hello-world
```

If Docker is not found, open **Docker Desktop** on Windows, go to
**Settings > Resources > WSL Integration**, and enable integration for your
Ubuntu distribution. Then restart your Ubuntu terminal.

---

## Step 6: Clone the repo

```bash
# Create a working directory in your Linux home folder
mkdir -p ~/projects && cd ~/projects

# Clone the repo (replace with your repo URL)
git clone https://github.com/Ch3w3y/docker_gcp.git
cd docker_gcp
```

Keep your project files inside WSL2 (`~/projects/...`), not on the Windows
filesystem (`/mnt/c/...`). File I/O across the WSL2 boundary is slow and can
cause issues with Docker bind mounts.

---

## Step 7: Open in Positron or VS Code

See [positron-setup.md](./positron-setup.md) for how to open the project in
Positron with the devcontainer running.

---

## Common issues

**`docker: permission denied`**
```bash
sudo usermod -aG docker $USER
# Then close and reopen your terminal
```

**Slow file performance**
Make sure your project is in your WSL2 home directory (`~/`), not under
`/mnt/c/Users/...`.

**`gcloud: command not found` after closing terminal**
Add this to `~/.bashrc`:
```bash
export PATH="$PATH:/usr/lib/google-cloud-sdk/bin"
```
Then run `source ~/.bashrc`.
