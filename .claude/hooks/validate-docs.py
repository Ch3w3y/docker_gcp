#!/usr/bin/env python3
"""PostToolUse hook: runs `mkdocs build --strict` after any docs/*.md edit.

Receives the tool's input as JSON on stdin. Exits non-zero (and prints errors
to stderr) if the build fails, so Claude can see and fix the issues immediately.
"""
import sys
import json
import subprocess

data = json.load(sys.stdin)
file_path = data.get("file_path", "")

# Only trigger for docs/*.md files
if "/docs/" not in file_path or not file_path.endswith(".md"):
    sys.exit(0)

# Find the project root so the command works regardless of CWD
git = subprocess.run(
    ["git", "rev-parse", "--show-toplevel"],
    capture_output=True, text=True,
)
if git.returncode != 0:
    sys.exit(0)

project_root = git.stdout.strip()

result = subprocess.run(
    ["mkdocs", "build", "--strict", "--quiet"],
    cwd=project_root,
    capture_output=True,
    text=True,
)

if result.returncode != 0:
    print("mkdocs build --strict FAILED after editing docs:", file=sys.stderr)
    # Print the first 2000 chars of stderr so errors are visible but not overwhelming
    print(result.stderr[:2000], file=sys.stderr)
    sys.exit(result.returncode)
else:
    print("mkdocs build --strict: OK")
