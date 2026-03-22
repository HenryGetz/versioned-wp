#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'EOF'
Usage: ./scripts/db-restore.sh <git-ref>

Examples:
  ./scripts/db-restore.sh HEAD~3
  ./scripts/db-restore.sh a1b2c3d

Restores the local WordPress database from the SQL snapshot tracked at:
  database/snapshots/wordpress-baseline.sql
in the specified git ref.
EOF
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

if ! command -v lando >/dev/null 2>&1; then
  echo "[db-restore] Missing dependency: lando" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[db-restore] Missing dependency: jq" >&2
  exit 1
fi

ref="$1"
snapshot_path="database/snapshots/wordpress-baseline.sql"
backup_path="/app/database/snapshots/pre-restore-backup.sql"
host_tmp_sql="/tmp/db-restore-target.sql"
container_tmp_sql="/tmp/db-restore-target.sql"

database_is_running() {
  local lando_info_json

  # `lando info --format json` is less error-prone than global `lando list` parsing.
  lando_info_json="$(lando info --format json 2>/dev/null || true)"
  jq -e '
    type == "array" and any(.[]; .service == "database")
  ' <<<"${lando_info_json}" >/dev/null 2>&1
}

cleanup() {
  rm -f "${host_tmp_sql}"
  lando exec appserver -- /bin/bash -lc "rm -f '${container_tmp_sql}'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! database_is_running; then
  echo "[db-restore] Lando is not running. Start it first with 'lando start'." >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
  echo "[db-restore] Error: git ref '${ref}' does not exist." >&2
  exit 1
fi

if ! git cat-file -e "${ref}:${snapshot_path}" 2>/dev/null; then
  recent_snapshot_refs="$(git log --oneline --all -- "${snapshot_path}" | head -5 || true)"

  echo "[db-restore] Error: No database snapshot found at git ref '${ref}'." >&2
  echo "[db-restore] The snapshot file (${snapshot_path}) does not exist in that commit." >&2
  echo "[db-restore] This usually means the commit was made before the DB sync pipeline was set up." >&2
  echo >&2
  echo "[db-restore] Available refs with snapshots:" >&2
  if [[ -n "${recent_snapshot_refs}" ]]; then
    printf '%s\n' "${recent_snapshot_refs}" >&2
  else
    echo "[db-restore] (none found)" >&2
  fi

  exit 1
fi

echo "[db-restore] Extracting ${snapshot_path} from git ref '${ref}'..."
if ! git show "${ref}:${snapshot_path}" > "${host_tmp_sql}"; then
  echo "[db-restore] Could not read ${snapshot_path} at ref '${ref}'." >&2
  exit 1
fi

if [[ ! -s "${host_tmp_sql}" ]]; then
  echo "[db-restore] Snapshot extracted from '${ref}' is empty. Aborting." >&2
  exit 1
fi

echo "[db-restore] Backing up current database to ${backup_path}..."
lando wp db export "${backup_path}" --path=/app/wordpress

echo "[db-restore] Uploading restore snapshot into container temp path..."
lando exec appserver -- /bin/bash -lc "cat > '${container_tmp_sql}'" < "${host_tmp_sql}"

echo "[db-restore] Importing snapshot from '${ref}'..."
lando wp db import "${container_tmp_sql}" --path=/app/wordpress

echo "[db-restore] Syncing Dolt working set..."
lando dolt -- add -A
if ! lando dolt -- commit -m "Restored DB to state from git ref: ${ref}"; then
  status_output="$(lando dolt -- status || true)"
  if [[ "${status_output}" == *"nothing to commit"* ]]; then
    echo "[db-restore] No Dolt commit created because restored state matched current state."
  else
    echo "[db-restore] Dolt commit failed unexpectedly." >&2
    echo "${status_output}" >&2
    exit 1
  fi
fi

echo "[db-restore] Restore complete from ref '${ref}'."
echo "[db-restore] Backup available at database/snapshots/pre-restore-backup.sql"
