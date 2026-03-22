#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SNAPSHOT_PATH="/app/database/snapshots/wordpress-baseline.sql"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/nuke-local.sh

WARNING: destroys and rebuilds the full local Lando environment.
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

echo "DANGER: This will destroy and rebuild your local environment (containers + DB)."
read -r -p "Type 'yes' to continue: " confirmation
if [[ "${confirmation}" != "yes" ]]; then
  echo "Canceled."
  exit 1
fi

if command -v lando >/dev/null 2>&1; then
  echo "Destroying local Lando app..."
  lando destroy -y

  echo "Starting fresh Lando app..."
  lando start

  echo "Importing baseline snapshot..."
  lando wp db import "${SNAPSHOT_PATH}" --path=/app/wordpress

  echo "Syncing Dolt..."
  lando dolt -- add -A
  if ! lando dolt -- commit -m "Rebuilt local from snapshot"; then
    status_output="$(lando dolt -- status || true)"
    if [[ "${status_output}" == *"nothing to commit"* ]]; then
      echo "No Dolt commit created because state already matched snapshot."
    else
      echo "Dolt commit failed unexpectedly."
      echo "${status_output}"
      exit 1
    fi
  fi

  echo "Running verification checks..."
  lando wp db check --path=/app/wordpress
  lando wp option get siteurl --path=/app/wordpress
else
  echo "[nuke] Lando CLI unavailable in this context; running in-container rebuild instead."

  wp db reset --yes --path=/app/wordpress
  wp db import "${SNAPSHOT_PATH}" --path=/app/wordpress

  mysql -hdatabase -uroot wordpress -e "CALL DOLT_ADD('-A');"
  if ! mysql -hdatabase -uroot wordpress -e "CALL DOLT_COMMIT('-m','Rebuilt local from snapshot');"; then
    status_count="$(wp db query "SELECT COUNT(*) FROM dolt_status;" --skip-column-names --path=/app/wordpress | tr -d '[:space:]' || echo '0')"
    if [[ "${status_count}" == "0" ]]; then
      echo "No Dolt commit created because state already matched snapshot."
    else
      echo "Dolt commit failed unexpectedly."
      exit 1
    fi
  fi

  wp db check --path=/app/wordpress
  wp option get siteurl --path=/app/wordpress
fi

echo "Done. Local environment rebuilt from snapshot."
