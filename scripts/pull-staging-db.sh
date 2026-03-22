#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# Replace CHANGEME values in setup:
# - CHANGEME-ssh-user / CHANGEME-ssh-host: SSH target for staging host.
# - CHANGEME-remote-path: absolute remote project root path (without /wordpress).
STAGING_SSH="CHANGEME-ssh-user@CHANGEME-ssh-host"
REMOTE_WP_PATH="CHANGEME-remote-path/wordpress"
TMP_SQL="/tmp/staging-pull.sql"
BACKUP_SQL="/app/database/snapshots/pre-pull-backup.sql"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/pull-staging-db.sh

Pulls the current staging database into local, then creates a Dolt commit.
Warning: this overwrites your local database state.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  echo "This script does not accept arguments."
  usage
  exit 1
fi

if [[ "${STAGING_SSH}" == CHANGEME-* || "${STAGING_SSH}" == *CHANGEME-* || "${REMOTE_WP_PATH}" == CHANGEME-* ]]; then
  echo "Replace CHANGEME placeholders in scripts/pull-staging-db.sh before running."
  exit 1
fi

if ! command -v lando >/dev/null 2>&1; then
  if ! command -v wp >/dev/null 2>&1 || ! command -v mysql >/dev/null 2>&1; then
    echo "Missing dependencies: require either lando or local wp/mysql commands"
    exit 1
  fi
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "Missing dependency: ssh"
  exit 1
fi

run_wp() {
  if command -v lando >/dev/null 2>&1; then
    lando wp "$@" --path=/app/wordpress
  else
    wp "$@" --path=/app/wordpress
  fi
}

run_dolt_commit() {
  local commit_message="$1"
  local sql_message

  if command -v lando >/dev/null 2>&1; then
    lando dolt -- add -A
    if ! lando dolt -- commit -m "${commit_message}"; then
      status_output="$(lando dolt -- status || true)"
      if [[ "${status_output}" == *"nothing to commit"* ]]; then
        echo "No Dolt commit created because pulled state matched current local DB."
      else
        echo "Dolt commit failed unexpectedly."
        echo "${status_output}"
        exit 1
      fi
    fi
  else
    sql_message="${commit_message//\'/\'\'}"
    mysql -hdatabase -uroot wordpress -e "CALL DOLT_ADD('-A');"
    if ! mysql -hdatabase -uroot wordpress -e "CALL DOLT_COMMIT('-m','${sql_message}');"; then
      status_count="$(run_wp db query "SELECT COUNT(*) FROM dolt_status;" --skip-column-names | tr -d '[:space:]' || echo '0')"
      if [[ "${status_count}" == "0" ]]; then
        echo "No Dolt commit created because pulled state matched current local DB."
      else
        echo "Dolt commit failed unexpectedly."
        exit 1
      fi
    fi
  fi
}

if command -v lando >/dev/null 2>&1 && ! lando info >/dev/null 2>&1; then
  echo "Lando is not running. Start it first with: lando start"
  exit 1
fi

echo "WARNING: This will overwrite your local WordPress database with staging content."
read -r -p "Type 'yes' to continue: " confirmation
if [[ "${confirmation}" != "yes" ]]; then
  echo "Canceled."
  exit 1
fi

local_url="$(run_wp option get siteurl | tr -d '\r')"
remote_siteurl_cmd="cd '${REMOTE_WP_PATH}' && wp option get siteurl"
staging_url="$(ssh "${STAGING_SSH}" "${remote_siteurl_cmd}" | tr -d '\r')"

if [[ -z "${local_url}" || -z "${staging_url}" ]]; then
  echo "Could not determine local or staging URL."
  exit 1
fi

echo "Exporting staging DB over SSH..."
remote_export_cmd="cd '${REMOTE_WP_PATH}' && wp db export -"
ssh "${STAGING_SSH}" "${remote_export_cmd}" > "${TMP_SQL}"

if [[ ! -s "${TMP_SQL}" ]]; then
  echo "Staging export failed: ${TMP_SQL} is empty"
  exit 1
fi

echo "Backing up local DB to ${BACKUP_SQL}..."
run_wp db export "${BACKUP_SQL}"

echo "Importing staging DB into local..."
run_wp db import "${TMP_SQL}"

echo "Rewriting staging URLs to local URL..."
run_wp search-replace "${staging_url}" "${local_url}" --all-tables --precise --recurse-objects --skip-columns=guid

echo "Syncing Dolt..."
run_dolt_commit "Pulled DB from staging"

echo "Done. Local DB now matches staging (with URLs rewritten to local)."
echo "Backup available at database/snapshots/pre-pull-backup.sql"
