#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

retry() {
  local attempts="$1"
  local delay_seconds="$2"
  shift 2

  local n
  for ((n = 1; n <= attempts; n++)); do
    if "$@"; then
      return 0
    fi
    if ((n < attempts)); then
      sleep "${delay_seconds}"
    fi
  done

  return 1
}

dolt_ready() {
  lando dolt version >/dev/null 2>&1
}

wp_db_ready() {
  lando wp db check --path=/app/wordpress >/dev/null 2>&1
}

cleanup_runtime_noise() {
  lando wp option delete _transient_doing_cron --path=/app/wordpress >/dev/null 2>&1 || true
  lando wp db query "DELETE FROM wp_options WHERE option_name REGEXP '^_site_transient(_timeout)?_wp_theme_files_patterns-';" --path=/app/wordpress >/dev/null 2>&1 || true
}

if ! command -v lando >/dev/null 2>&1; then
  echo "Missing dependency: lando"
  echo "Install Lando + Docker first, then rerun ./scripts/setup-dev.sh"
  exit 1
fi

hooks_path="$(git config --get core.hooksPath || true)"
if [[ "${hooks_path}" != ".githooks" ]]; then
  echo "Configuring git hooks path..."
  git config core.hooksPath .githooks
fi

echo "Starting Lando..."
lando start

echo "Running connectivity checks..."
retry 30 2 dolt_ready
retry 30 2 wp_db_ready
# WordPress can leave cron lock transients that create noisy, non-meaningful Dolt diffs.
cleanup_runtime_noise

commit_count="$(lando dolt-log | sed -r 's/\x1B\[[0-9;]*[mK]//g' | awk '/^commit / { c++ } END { print c + 0 }')"

echo "Ensuring Dolt identity is configured..."
# CHANGEME-dev-name / CHANGEME-dev-email should be replaced with your identity.
lando dolt config --local --set user.name "CHANGEME-dev-name"
lando dolt config --local --set user.email "CHANGEME-dev-email"

status_output="$(lando dolt status || true)"
if [[ "${status_output}" != *"nothing to commit"* && "${commit_count}" -le 1 ]]; then
  echo "Staging and committing DB snapshot to Dolt..."
  lando dolt add -A
  lando dolt commit -m "Baseline: imported existing WordPress database" || true
elif [[ "${status_output}" != *"nothing to commit"* ]]; then
  echo "Dolt has uncommitted changes; leaving them untouched."
fi

site_url="$(lando wp option get siteurl --path=/app/wordpress)"
page_count="$(lando wp post list --post_type=page --format=count --path=/app/wordpress)"
commit_count="$(lando dolt-log | sed -r 's/\x1B\[[0-9;]*[mK]//g' | awk '/^commit / { c++ } END { print c + 0 }')"

echo "Setup complete."
echo "Site URL: ${site_url}"
echo "Page count: ${page_count}"
echo "Dolt commits: ${commit_count}"
