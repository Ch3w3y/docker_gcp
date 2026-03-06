# Setting Up WSL2 on Windows 11 Enterprise

This guide walks through getting a Linux development environment running on a
Windows 11 Enterprise laptop. Complete this before following the Positron setup guide.

---

## Why we use WSL2

Our Docker containers run Ubuntu Linux. Cloud Run also runs Ubuntu Linux. To
get the most faithful local development environment — and to avoid a class of
filesystem and path problems that occur on Windows — we run our development
tools inside Linux on your Windows machine.

**WSL2** (Windows Subsystem for Linux 2) is a feature built into Windows 11
that runs a genuine Linux kernel inside a lightweight virtual machine. It is
not emulation — it is a real Linux environment. You can run `bash`, install
Linux packages with `apt`, and run Docker containers, all from within Windows.

The result: your laptop runs Windows for everything else, but your data
engineering work happens inside Ubuntu, in an environment that closely matches
both the devcontainer and the cloud.

---

## Before you start: contact IT

Windows 11 Enterprise restricts some features by default. You will need IT to
install and enable the following before proceeding:

| What to request | Why it is needed |
|---|---|
| WSL2 (Windows Subsystem for Linux 2) with Ubuntu | Provides the Linux environment |
| Docker Desktop with WSL2 backend enabled | Runs containers locally |
| Windows Terminal | A proper terminal application (better than Command Prompt) |

When raising the request, quote exactly:

!!! tip "What to say to IT"
    *"Please install WSL2 with an Ubuntu 24.04 distribution and Docker Desktop
    with the WSL2 backend integration enabled. Also install Windows Terminal."*

    This phrasing helps IT understand precisely what is needed.

---

## Step 1: Verify WSL2 and Ubuntu are installed

Once IT confirms setup is complete, open **Windows Terminal** (search for it in
the Start menu) and run the following in a PowerShell tab:

```powershell
wsl --list --verbose
```

Expected output:

```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

The `VERSION` column must be `2`. Version `1` is an older implementation that
does not run Docker correctly — contact IT if you see it.

If you see an empty list or an error, WSL2 has not been installed. Contact IT.

---

## Step 2: Open an Ubuntu terminal

In Windows Terminal, click the dropdown arrow (`v`) next to the `+` tab and
select **Ubuntu**. A bash prompt appears — you are now inside Linux.

The first time you open Ubuntu, you will be prompted to create a Linux username
and password. These are separate from your Windows credentials. Choose something
simple; you will type the password when running `sudo` commands.

Update your package lists:

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

This may take a few minutes the first time.

---

## Step 3: Configure git

Git is pre-installed in Ubuntu. Configure your identity — this is what appears
on your commits:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@organisation.gov.uk"
```

Set the default branch name to `main` (consistent with GitHub's default):

```bash
git config --global init.defaultBranch main
```

---

## Step 4: Set up GitHub authentication

You need to authenticate to GitHub from your Linux environment to push and pull
code. The simplest approach is the GitHub CLI.

```bash
sudo apt-get install -y gh
gh auth login
```

When prompted:
1. Select **GitHub.com**
2. Select **HTTPS**
3. Select **Login with a web browser**
4. Copy the code shown, press Enter — a browser window opens
5. Paste the code and authorise

Verify it worked:

```bash
gh auth status
```

You should see your username and a confirmation that you are logged in.

---

## Step 5: Install the Google Cloud CLI

The `gcloud` CLI lets you authenticate to GCP and run cloud commands from
your terminal.

```bash
sudo apt-get install -y apt-transport-https ca-certificates gnupg

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
  https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

sudo apt-get update && sudo apt-get install -y google-cloud-cli
```

Verify:

```bash
gcloud --version
```

---

## Step 6: Authenticate to GCP

Sign in with your work Google account:

```bash
gcloud auth login
```

A browser window opens. Sign in and grant the requested permissions.

Set your default project:

```bash
gcloud config set project YOUR_PROJECT_ID
```

Replace `YOUR_PROJECT_ID` with your GCP project ID (ask your platform team if
you are unsure what this is).

Then set up **Application Default Credentials (ADC)**. These are what the R and
Python GCP client libraries use to authenticate automatically:

```bash
gcloud auth application-default login
```

Sign in again when prompted. This stores credentials in
`~/.config/gcloud/application_default_credentials.json`. You only need to run
this once per machine; the credentials are refreshed automatically.

!!! note "ADC credentials expire"
    ADC credentials have a long but finite lifetime. If you start seeing
    authentication errors after weeks of not using GCP, re-run
    `gcloud auth application-default login`.

---

## Step 7: Verify Docker works inside WSL2

```bash
docker --version
docker run --rm hello-world
```

If `docker: command not found`, open **Docker Desktop on Windows**, go to
**Settings > Resources > WSL Integration**, enable the toggle for your Ubuntu
distribution, and click **Apply & Restart**. Then close and reopen your Ubuntu
terminal.

Expected output from `hello-world`:

```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

---

## Step 8: Clone the repo

Create a projects directory in your Linux home folder and clone the repo:

```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/Ch3w3y/docker_gcp.git
cd docker_gcp
```

!!! warning "Keep your files in WSL2, not on the Windows filesystem"
    Always keep project files inside your WSL2 home directory (`~/projects/...`),
    not on the Windows filesystem (`/mnt/c/Users/...`).

    Files under `/mnt/c/` cross the WSL2 boundary for every read and write
    operation, which is significantly slower and can cause issues with Docker
    bind mounts. The Linux filesystem (`~/`) does not have this problem.

---

## Step 9: Open in Positron

See [positron-setup.md](./positron-setup.md) for how to open the project in
Positron and connect to the devcontainer.

---

## Keeping your environment healthy

A few habits that prevent most WSL2 problems:

**Update regularly**

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

Running this weekly keeps your Ubuntu packages current.

**Refresh GCP credentials periodically**

```bash
gcloud auth application-default login
```

ADC credentials have a long but finite lifetime. If GCP calls start failing
with `401 Unauthorized`, this is usually the cause.

**Check Docker Desktop is running**

Docker Desktop on Windows must be running for `docker` commands to work in
WSL2. If you get `Cannot connect to the Docker daemon`, check the Docker
Desktop icon in the system tray.

---

## Common issues

**`docker: permission denied while connecting to the Docker daemon`**

Your Linux user is not in the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

If `newgrp` does not help, close and reopen your Ubuntu terminal.

**`gcloud: command not found` after closing terminal**

The `gcloud` binary path is not in your shell's `PATH`. Add it:

```bash
echo 'export PATH="$PATH:/usr/lib/google-cloud-sdk/bin"' >> ~/.bashrc
source ~/.bashrc
```

**Slow performance when working with files**

You are probably working under `/mnt/c/`. Move your project to `~/projects/`.

**`git push` asks for a username and password every time**

Your GitHub CLI authentication is not being used by git. Run:

```bash
gh auth setup-git
```

This configures git to use the GitHub CLI as its credential helper.

**WSL2 cannot resolve hostnames**

This is a known DNS issue on some corporate networks. Try:

```bash
echo -e "[network]\ngenerateResolvConf = false" | sudo tee /etc/wsl.conf
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

Then restart WSL2 from PowerShell: `wsl --shutdown`, then reopen Ubuntu.
