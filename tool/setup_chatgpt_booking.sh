#!/usr/bin/env bash
# Generate an assistant-only credential and store it in GitHub Actions secrets.
set -euo pipefail

repo='alex00Pirotskyi/evil_space'
if [[ ! -t 0 ]]; then
  echo 'Run this script in an interactive terminal so you can save the key.' >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
  echo 'Install GitHub CLI and Node.js first.' >&2
  exit 1
fi
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo 'Sign in to GitHub first using gh auth login.' >&2
  exit 1
fi

assistant_key="$(node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('base64url'))")"
printf '%s' "$assistant_key" | gh secret set ASSISTANT_BOOKING_KEY --app actions --repo "$repo"

echo 'Saved ASSISTANT_BOOKING_KEY as a GitHub Actions secret.'
echo 'Copy this key to your private ChatGPT Action authentication settings now.'
echo 'It is shown once here and cannot be retrieved from GitHub later:'
printf '%s\n' "$assistant_key"
unset assistant_key
echo 'After saving the key in ChatGPT, run make to send it to the Cloudflare Worker.'
