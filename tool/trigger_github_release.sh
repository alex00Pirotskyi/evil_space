#!/usr/bin/env bash
# Start the production build on GitHub, where the Cloudflare secrets are stored.
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo 'Install GitHub CLI first: https://cli.github.com/' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo 'Sign in once with: gh auth login --hostname github.com --web' >&2
  exit 1
fi

echo 'Starting Production release for the latest GitHub main branch...'
gh workflow run release.yml --ref main --repo alex00Pirotskyi/evil_space
echo 'GitHub is building and deploying the Flutter app, Worker and SEO pages.'
echo 'View progress: https://github.com/alex00Pirotskyi/evil_space/actions/workflows/release.yml'
