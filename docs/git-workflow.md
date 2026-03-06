# The GitHub Workflow

This page covers the day-to-day workflow for making changes to pipeline code — branching, committing, opening pull requests, and merging. It assumes you have read [What Is Version Control?](git-fundamentals.md), which covers Git concepts and commands from first principles.

If you are not sure what a branch or a commit is, start there.

---

## How the workflow protects production

The `main` branch is protected. You cannot push directly to it. The only way code reaches `main` is through a pull request that:

1. Has passed automated tests (pytest and testthat run automatically on every PR)
2. Has been approved by at least one reviewer

This means every change to your pipeline has been reviewed and tested before it reaches the GCS bucket and runs in Cloud Run. No change can break production without someone having looked at it.

---

## How the workflow protects production

The `main` branch is protected. You cannot push directly to it. The only way
code reaches `main` is through a pull request that:

1. Has passed automated tests (pytest and testthat run automatically)
2. Has been approved by at least one reviewer

This means every change to your pipeline has been reviewed and tested before
it reaches the GCS bucket and runs in Cloud Run.

---

## Core concepts

| Term | What it means |
|---|---|
| **Repository (repo)** | The folder containing all your code and its full history |
| **Commit** | A saved snapshot of changes, with a message describing what changed |
| **Branch** | An independent line of development — changes on a branch do not affect `main` |
| **Pull request (PR)** | A request to merge changes from your branch into `main`, with a review step |
| **Merge** | Incorporating one branch's changes into another |
| **Clone** | Downloading a copy of a remote repo to your machine |
| **Push** | Uploading your local commits to GitHub |
| **Pull** | Downloading new commits from GitHub to your local machine |

---

## The standard workflow

Every piece of work — however small — follows this pattern:

```
main ──────────────────────────────────────────── (protected)
         │                             │
         └── your-branch ── commits ──┘
                                  (merged via pull request)
```

### Step 1: Start from an up-to-date main

Before starting any new piece of work, get the latest version of `main`:

```bash
git checkout main
git pull
```

### Step 2: Create a branch

Give the branch a short, descriptive name using hyphens. It does not need to
be formal — just clear enough that a colleague understands what it contains.

```bash
git checkout -b add-monthly-summary-table
```

Good branch names: `fix-null-handling`, `add-output-table`, `update-extract-query`

Poor branch names: `test`, `fix`, `my-changes`, `branch1`

### Step 3: Make your changes and commit

After editing files, stage and commit them. A commit is a logical unit of work
— aim for one commit per meaningful change rather than committing every file
save.

```bash
# See what has changed
git status

# Stage specific files (preferred over `git add .`)
git add src/load.R tests/testthat/test_pipeline.R

# Commit with a descriptive message
git commit -m "add monthly summary output table to load step"
```

**Writing a good commit message**: describe what the change does and, where
relevant, why. Future-you and your colleagues will read these messages when
investigating production issues.

Good: `fix null handling in extract step when BigQuery returns empty result`
Poor: `fix`, `update`, `wip`, `asdfgh`

### Step 4: Push the branch to GitHub

```bash
git push -u origin add-monthly-summary-table
```

The `-u` flag sets the upstream tracking branch so future `git push` calls on
this branch do not need the full remote and branch name.

### Step 5: Open a pull request

After pushing, GitHub displays a banner in the repository suggesting you open
a pull request. Click it, or go to the **Pull requests** tab and click
**New pull request**.

Fill in:
- **Title**: a one-line summary of what the PR does
- **Description**: what problem it solves, how you tested it locally, and
  anything the reviewer should pay attention to

GitHub Actions automatically runs your tests when the PR is opened. You will
see a status check below the description — a green tick means tests passed, a
red cross means they failed and should be fixed before asking for review.

### Step 6: Respond to review

A colleague reviews your changes and may leave comments requesting changes.
Address each comment by editing your code and adding new commits to the same
branch:

```bash
# Make the requested changes
git add src/load.R
git commit -m "address review: handle empty dataframe in load step"
git push
```

The PR updates automatically. You do not need to open a new pull request.

### Step 7: Merge

Once the reviewer approves and tests are green, merge the pull request on
GitHub using the **Merge pull request** button. Your changes are now on `main`,
and GitHub Actions will sync the code to GCS.

Delete the branch after merging — GitHub offers this automatically. Keeping
stale branches around clutters the repository.

---

## Keeping your branch up to date

If `main` receives new commits while you are working on your branch, you may
need to bring those changes into your branch before merging. The safest way:

```bash
git checkout main
git pull
git checkout your-branch-name
git merge main
```

If there are **merge conflicts** (two people edited the same lines), Git will
mark the conflicting sections in the file:

```
<<<<<<< HEAD
your version of the code
=======
incoming version from main
>>>>>>> main
```

Edit the file to keep the correct version, remove the conflict markers, then:

```bash
git add the-file-with-conflicts.R
git commit -m "merge main and resolve conflict in load step"
git push
```

---

## Common commands reference

```bash
# See the current state of your working directory
git status

# See what has changed in each file
git diff

# See the commit history
git log --oneline

# Switch to an existing branch
git checkout branch-name

# Create and switch to a new branch
git checkout -b new-branch-name

# Stage a specific file
git add path/to/file.R

# Unstage a file (undo a git add before committing)
git restore --staged path/to/file.R

# Discard uncommitted changes to a file (permanent — use with care)
git restore path/to/file.R

# Amend the most recent commit message (before pushing only)
git commit --amend -m "corrected commit message"

# Pull latest changes from GitHub
git pull

# Push current branch to GitHub
git push

# List all branches
git branch -a
```

---

## What not to do

!!! danger "Never commit `.env` files"
    `.env` files contain credentials and project-specific values that must not
    be shared. The `.gitignore` in this repo prevents them from being staged
    accidentally, but be aware of the risk if you create files with other names.

!!! warning "Do not push directly to `main`"
    Branch protection prevents this, but even if it did not — changes to `main`
    bypass the test and review process and go directly to production.

!!! warning "Do not use `git push --force` on shared branches"
    This rewrites history and can destroy your colleagues' work. If you think
    you need it, ask first.

!!! tip "Do not commit data files"
    Git is designed for code, not data. Files over a few megabytes will slow
    down every clone and pull for everyone on the team. Keep data in GCS.

---

## Further reading

- [Pro Git book (free)](https://git-scm.com/book/en/v2) — comprehensive reference
- [GitHub's git guides](https://github.com/git-guides) — short, practical walkthroughs
- [Oh Shit, Git!](https://ohshitgit.com) — how to recover from common mistakes
