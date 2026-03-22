#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SQL_SNAPSHOT="database/snapshots/wordpress-baseline.sql"
LOG_SNAPSHOT="database/snapshots/dolt-log.txt"
LOCAL_SITEURL_FILE="database/LOCAL_SITEURL"
MODE="manual"
did_dolt_commit="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/db-sync-github.sh [message]
  ./scripts/db-sync-github.sh --pre-commit [message]

Modes:
  manual      Start Lando (if needed), sync Dolt + SQL snapshots, then create a git commit.
  pre-commit  If Lando DB container is running, commit pending Dolt table changes and stage
              database artifacts. Skip silently when Lando is not running.
EOF
}

if ! command -v lando >/dev/null 2>&1; then
  echo "Missing dependency: lando"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing dependency: jq"
  exit 1
fi

message_input=""
while (($#)); do
  case "$1" in
    --pre-commit)
      MODE="pre-commit"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -n "${message_input}" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage
        exit 1
      fi
      message_input="$1"
      shift
      ;;
  esac
done

database_is_running() {
  local lando_info_json

  # `lando list --format json` can occasionally emit truncated output in non-interactive hooks.
  # `lando info --format json` is scoped to the current app and has proven more reliable.
  lando_info_json="$(lando info --format json 2>/dev/null || true)"
  jq -e '
    type == "array" and any(.[]; .service == "database")
  ' <<<"${lando_info_json}" >/dev/null 2>&1
}

cleanup_runtime_noise() {
  # Ignore common runtime transient noise before status checks.
  lando wp option delete _transient_doing_cron --path=/app/wordpress >/dev/null 2>&1 || true
  lando wp db query "DELETE FROM wp_options WHERE option_name REGEXP '^_site_transient(_timeout)?_wp_theme_files_patterns-';" --path=/app/wordpress >/dev/null 2>&1 || true
}

export_sql_snapshot() {
  local site_url

  echo "[db-sync] Exporting SQL snapshot..."
  lando wp db export "/app/${SQL_SNAPSHOT}" --path=/app/wordpress

  # Remove MariaDB sandbox pragma, which can break imports on some engines.
  sed -i '1{/^\/\*M!999999\\- enable the sandbox mode \*\/ *$/d;}' "${SQL_SNAPSHOT}"

  echo "[db-sync] Writing local site URL artifact..."
  site_url="$(lando wp option get siteurl --path=/app/wordpress | tr -d '\r')"
  printf '%s\n' "${site_url}" > "${LOCAL_SITEURL_FILE}"
}

dolt_is_clean() {
  local status_output
  status_output="$(lando dolt -- status)"
  [[ "${status_output}" == *"nothing to commit"* ]]
}

sync_dolt_commit() {
  local commit_message="$1"

  if dolt_is_clean; then
    echo "[db-sync] Database clean, nothing to sync"
    return 0
  fi

  echo "[db-sync] Committing pending Dolt DB changes..."
  lando dolt -- add -A
  if ! lando dolt -- commit -m "${commit_message}"; then
    # If another process resolved changes between status and commit, do not block git commit.
    if dolt_is_clean; then
      echo "[db-sync] Database clean, nothing to sync"
      return 0
    fi
    echo "[db-sync] Failed to create Dolt commit" >&2
    return 1
  fi

  did_dolt_commit="true"

  # Keep the GitHub-tracked commit history artifact in sync with the new Dolt commit.
  lando dolt-log | sed -r 's/\x1B\[[0-9;]*[mK]//g' > "${LOG_SNAPSHOT}"

  git add database/
  echo "[db-sync] Staged updated database artifacts"
}

if [[ "${MODE}" == "pre-commit" ]]; then
  if ! database_is_running; then
    echo "[db-sync] Lando not running, skipping DB sync"
    exit 0
  fi

  short_git_desc="$(git describe --always --dirty --abbrev=12 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  message="${message_input:-auto: pre-commit sync ${short_git_desc}}"

  cleanup_runtime_noise
  sync_dolt_commit "${message}"

  if [[ "${did_dolt_commit}" == "true" ]]; then
    export_sql_snapshot
    git add database/
    echo "[db-sync] Staged SQL snapshot for database deployment"
  fi

  exit 0
fi

MESSAGE="${message_input:-Database update from WordPress admin ($(date -u +%Y-%m-%dT%H:%M:%SZ))}"

echo "Ensuring Lando is running..."
lando start >/dev/null

cleanup_runtime_noise
sync_dolt_commit "${MESSAGE}"

export_sql_snapshot

echo "Exporting Dolt commit log snapshot..."
lando dolt-log | sed -r 's/\x1B\[[0-9;]*[mK]//g' > "${LOG_SNAPSHOT}"

echo "Staging database artifacts in git..."
git add database/dolt "${SQL_SNAPSHOT}" "${LOG_SNAPSHOT}" "${LOCAL_SITEURL_FILE}"

if git diff --cached --quiet; then
  echo "No Git-tracked DB artifact changes detected."
  exit 0
fi

echo "Creating git commit for DB artifacts..."
git commit -m "${MESSAGE}"

echo "Done."
echo "Next step: git push"
