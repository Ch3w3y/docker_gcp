# Troubleshooting Common Issues

This page covers the most common problems analysts run into when setting up and using
this workflow, with diagnosis steps and fixes for each one.

---

## Contents

1. [WSL2: clock drift causes TLS and authentication errors](#wsl2-clock-drift)
2. [Docker: permission denied on /var/run/docker.sock](#docker-permission-denied)
3. [renv: package installation fails during Docker build](#renv-docker-build-failure)
4. [BigQuery: authentication error when running locally](#bigquery-auth-error)
5. [run.sh: pipeline fails with no error message](#pipeline-silent-failure)
6. [git: push rejected — branch protection](#push-rejected-branch-protection)
7. [Docker: container starts but exits immediately](#container-exits-immediately)
8. [Cloud Run: job succeeds but output is missing](#job-succeeds-output-missing)

---

## WSL2: clock drift causes TLS and authentication errors {#wsl2-clock-drift}

**Symptoms:** `gcloud auth application-default login` fails with a TLS certificate error.
Docker pulls fail. Google API calls return "clock skew" or `invalid_grant` errors.

**Cause:** WSL2's Linux kernel can fall out of sync with the Windows system clock, especially
after the laptop has slept or been suspended.

**Fix:**

```bash
# Force WSL2 to resync its clock with Windows
sudo hwclock -s
```

Or restart the WSL2 VM entirely (run this in PowerShell on Windows, not in the Ubuntu terminal):

```bash
wsl --shutdown
```

Then reopen your Ubuntu terminal. To prevent this recurring, add the sync to your `~/.bashrc`:

```bash
# Add this line to ~/.bashrc
sudo hwclock -s 2>/dev/null
```

---

## Docker: permission denied on /var/run/docker.sock {#docker-permission-denied}

**Symptoms:** `docker compose run ...` or `docker build ...` fails with:

```
permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

**Cause:** Your Linux user account is not in the `docker` group.

**Fix:**

```bash
sudo usermod -aG docker $USER
```

Close and reopen your terminal (or run `newgrp docker` to apply the group change immediately
without restarting). Verify the fix with:

```bash
docker run --rm hello-world
```

---

## renv: package installation fails during Docker build {#renv-docker-build-failure}

**Symptoms:** `docker build` fails partway through `renv::restore()` with a CRAN timeout,
a missing system library, or a compilation error.

**Diagnosis — see the full error:**

```bash
# Build with verbose output and no layer cache
docker build --no-cache --progress=plain -t gcp-etl:debug ./gcp-etl 2>&1 | tail -80
```

**Common causes and fixes:**

| What you see | Cause | Fix |
|---|---|---|
| `Timeout was reached` | CRAN mirror temporarily unavailable | Retry — usually resolves on second attempt |
| `libXYZ not found` or `configure: error` | R package needs a system library not in the Dockerfile | Open a PR adding the `apt-get install libXYZ-dev` line to the Dockerfile |
| `package 'XYZ' is not available` | Package version in `renv.lock` removed from CRAN | Run `renv::update("XYZ")` inside a container shell then `renv::snapshot()` |

---

## BigQuery: authentication error when running locally {#bigquery-auth-error}

**Symptoms:** `docker compose run --rm pipeline` fails with:

```
Error: Unable to find Application Default Credentials.
```

Or in Python: `google.auth.exceptions.DefaultCredentialsError`.

**Cause:** Application Default Credentials (ADC) have not been set up, or have expired.

**Fix:**

```bash
# Run this in your WSL2 Ubuntu terminal — not inside a container
gcloud auth application-default login
```

Follow the browser prompts to authenticate. Then retry the pipeline.

If the error persists, verify the credentials file exists:

```bash
ls ~/.config/gcloud/application_default_credentials.json
```

The `docker-compose.yml` mounts this file into the container. If it is missing, the mount
fails silently and ADC is unavailable inside the container.

---

## run.sh: pipeline fails with no error message {#pipeline-silent-failure}

**Symptoms:** The container exits with a non-zero status but no R error appears in the output.
Or `docker compose run --rm pipeline` exits immediately with minimal output.

**Cause:** `set -euo pipefail` in `run.sh` causes the shell to exit immediately when any
command fails. If the failing command exits before flushing its output buffer, the error message
may not appear.

**Diagnosis:**

```bash
# Run the container interactively
docker compose run --rm pipeline bash

# Inside the container, run with bash tracing
cd /workspace
bash -x run.sh
```

The `-x` flag prints each command before executing it, which shows exactly which command
triggered the exit.

---

## git: push rejected — branch protection {#push-rejected-branch-protection}

**Symptoms:** `git push origin main` is rejected with:

```
remote: error: GH006: Protected branch update failed for refs/heads/main
```

**Cause:** `main` is branch-protected. Direct pushes are intentionally blocked — this is
working as intended.

**Fix:** Always work on a branch:

```bash
git checkout -b my-feature-branch
# make your changes and commit them
git push -u origin my-feature-branch
# then open a pull request on GitHub
```

Branch protection ensures every change is reviewed before reaching production. It is not
an error to work around — it is the workflow.

---

## Docker: container starts but exits immediately {#container-exits-immediately}

**Symptoms:** `docker compose run --rm pipeline` exits in under a second with little or no output.

**Cause:** Most commonly a missing environment variable that `config.R` is catching, or a
syntax error in `run.sh`.

**Diagnosis:**

```bash
# Override the default command with an interactive shell
docker compose run --rm pipeline bash

# Inside the container, run the pipeline manually
cd /workspace
bash run.sh
```

If `config.R` is sourced at the start of the pipeline, it will print which environment
variables are missing before stopping. Check that your `.env` file exists and contains
all the variables listed in `.env.example`.

---

## Cloud Run: job succeeds but output is missing {#job-succeeds-output-missing}

**Symptoms:** Cloud Logging shows the job completed successfully (exit code 0) but the
expected BigQuery table or GCS file is not present.

**Common causes:**

1. **Wrong destination** — the load step wrote to a table or bucket name from the wrong
   environment variable. Check Secret Manager values match what the pipeline expects.
2. **Write to /tmp but no upload** — the pipeline saved output to `/tmp/` inside the container
   but the upload step did not run (perhaps a previous step failed and `set -e` skipped it).
3. **IAM permissions** — the service account does not have write access to the destination.

**Diagnosis:**

```bash
# Read the full job log
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="YOUR_JOB_NAME"' \
  --project=YOUR_PROJECT_ID \
  --limit=100 \
  --format="value(timestamp, textPayload)"
```

Check IAM: the service account needs `roles/bigquery.dataEditor` to write to BigQuery and
`roles/storage.objectCreator` to write to GCS.
