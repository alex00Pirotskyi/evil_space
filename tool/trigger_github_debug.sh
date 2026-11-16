#!/usr/bin/env bash
# Use GitHub Actions to deploy checked-in staging changes.
set -euo pipefail
if ! command -v gh >/dev/null 2>&1; then
  echo 'GitHub CLI required: https://cli.github.com/' >&2
  exit 1
fi
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo 'Sign in once with: gh auth login --hostname github.com --web' >&2
  exit 1
fi
gh workflow run debug.yml --ref main --repo alex00Pirotskyi/evil_space
echo 'Staging workflow: https://github.com/alex00Pirotskyi/evil_space/actions/workflows/debug.yml'
echo 'Only checked-in main-branch code is deployed; push local changes first.'
