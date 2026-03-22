#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

LOCAL_SITEURL_FILE="${ROOT_DIR}/database/LOCAL_SITEURL"
LOCAL_URL=""
# Replace CHANGEME values in setup:
# - CHANGEME-staging-url: staging domain (without protocol).
# - CHANGEME-ssh-user / CHANGEME-ssh-host: SSH target for staging host.
# - CHANGEME-remote-path: absolute remote project root path.
STAGING_URL="https://CHANGEME-staging-url"
STAGING_SSH="CHANGEME-ssh-user@CHANGEME-ssh-host"
STAGING_PATH="CHANGEME-remote-path"

if [[ "$#" -ne 0 ]]; then
  echo "This script does not accept arguments."
  exit 1
fi

if [[ "$STAGING_SSH" == CHANGEME-* || "$STAGING_PATH" == CHANGEME-* || "$STAGING_URL" == *CHANGEME-* ]]; then
  echo "Replace CHANGEME placeholders in scripts/deploy-staging.sh before running."
  exit 1
fi

if [[ -s "${LOCAL_SITEURL_FILE}" ]]; then
  LOCAL_URL="$(tr -d '\r\n' < "${LOCAL_SITEURL_FILE}")"
else
  LOCAL_URL="$(lando wp option get siteurl --path=/app/wordpress | tr -d '\r')"
fi

if [[ -z "${LOCAL_URL}" ]]; then
  echo "Unable to determine local source URL for search-replace."
  exit 1
fi

TMP_DIR="${ROOT_DIR}/.tmp"
mkdir -p "${TMP_DIR}"

raw_sql="$(mktemp "${TMP_DIR}/staging-raw.XXXXXX.sql")"
rewritten_sql="$(mktemp "${TMP_DIR}/staging-rewritten.XXXXXX.sql")"
remote_tmp="/tmp/$(basename "$rewritten_sql")"

cleanup() {
  rm -f "$raw_sql" "$rewritten_sql"
  ssh "$STAGING_SSH" "rm -f '$remote_tmp'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Ignore transient cron lock noise before checking for real pending DB changes.
lando wp option delete _transient_doing_cron --path=/app/wordpress >/dev/null 2>&1 || true

status_output="$(lando dolt status || true)"
if [[ "$status_output" != *"nothing to commit"* ]]; then
  echo "Warning: uncommitted Dolt changes detected:"
  echo "$status_output"
  read -r -p "Continue deployment anyway? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Deployment aborted."
    exit 1
  fi
fi

echo "Exporting local DB..."
lando wp db export "/app/.tmp/$(basename "$raw_sql")" --path=/app/wordpress

echo "Rewriting local URLs to staging URL..."
python3 - "$raw_sql" "$rewritten_sql" "$LOCAL_URL" "$STAGING_URL" <<'PY'
from pathlib import Path
import sys

raw_path, rewritten_path, source_url, staging_url = sys.argv[1:5]
raw_sql = Path(raw_path).read_text(encoding="utf-8")
Path(rewritten_path).write_text(raw_sql.replace(source_url, staging_url), encoding="utf-8")
PY

echo "Uploading SQL dump to staging..."
scp "$rewritten_sql" "${STAGING_SSH}:${remote_tmp}"

echo "Importing SQL on staging..."
ssh "$STAGING_SSH" "cd '$STAGING_PATH/wordpress' && wp db import '$remote_tmp'"

echo "Running serialized-safe URL replacement on staging..."
ssh "$STAGING_SSH" "cd '$STAGING_PATH/wordpress' && wp search-replace '$LOCAL_URL' '$STAGING_URL' --all-tables --precise --recurse-objects --skip-columns=guid"

echo "Staging deploy complete."
