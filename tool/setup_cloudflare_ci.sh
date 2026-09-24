#!/usr/bin/env bash
# Store Cloudflare release credentials in this repository's GitHub Actions secrets.
set -euo pipefail

repo='alex00Pirotskyi/evil_space'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -t 0 ]]; then
  echo 'Run this script in an interactive terminal.' >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo 'Install GitHub CLI first: https://cli.github.com/' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo 'Sign in to GitHub to set repository Actions secrets.'
  gh auth login --hostname github.com --web
fi

account_id="${CLOUDFLARE_ACCOUNT_ID:-}"
if [[ -z "$account_id" ]] && command -v npx >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  wrangler_version="$(<"$script_dir/wrangler_version.txt")"
  echo 'Checking Cloudflare account via Wrangler (this may take a minute)...'
  if whoami_json="$(npx --yes "wrangler@$wrangler_version" whoami --json 2>/dev/null)"; then
    account_id="$(printf '%s' "$whoami_json" | node -e '
      let input = "";
      process.stdin.on("data", chunk => input += chunk);
      process.stdin.on("end", () => {
        try {
          const info = JSON.parse(input);
          const accounts = info.accounts ?? info.result?.accounts ?? [];
          const entries = Array.isArray(accounts) ? accounts : Object.values(accounts);
          const ids = [...new Set(entries.map(account => account?.id ?? account?.account_id)
            .filter(id => typeof id === "string" && /^[a-f0-9]{32}$/i.test(id)))];
          if (ids.length === 1) process.stdout.write(ids[0]);
        } catch (_) { /* Ask the user for the ID below. */ }
      });
    ')"
  fi
fi

if [[ -n "$account_id" ]]; then
  echo "Cloudflare account ID: $account_id"
  read -r -p 'Press Enter to use this ID, or paste the correct account ID: ' chosen_id
  account_id="${chosen_id:-$account_id}"
else
  echo 'Find the account ID in Cloudflare > Workers & Pages > Account Details.'
  read -r -p 'Cloudflare account ID: ' account_id
fi

if [[ ! "$account_id" =~ ^[a-fA-F0-9]{32}$ ]]; then
  echo 'Cloudflare account ID must be 32 hexadecimal characters.' >&2
  exit 1
fi

echo 'Paste the Cloudflare API token you created for Workers and D1; input is hidden.'
read -r -s -p 'Cloudflare API token: ' cloudflare_token
echo
if [[ -z "$cloudflare_token" ]]; then
  echo 'No token supplied; no secrets were changed.' >&2
  exit 1
fi

printf '%s' "$cloudflare_token" | gh secret set CLOUDFLARE_API_TOKEN --app actions --repo "$repo"
unset cloudflare_token
printf '%s' "$account_id" | gh secret set CLOUDFLARE_ACCOUNT_ID --app actions --repo "$repo"

echo "Both Actions secrets are set for $repo."
echo 'This only configures the release workflow; it does not deploy the site.'
