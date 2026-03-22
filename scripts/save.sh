#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/save.sh "Describe what you finished"

If no message is provided, the script prompts for one.
EOF
}

cleanup_runtime_noise() {
  if command -v lando >/dev/null 2>&1; then
    lando wp option delete _transient_doing_cron --path=/app/wordpress >/dev/null 2>&1 || true
    lando wp db query "DELETE FROM wp_options WHERE option_name REGEXP '^_site_transient(_timeout)?_wp_theme_files_patterns-';" --path=/app/wordpress >/dev/null 2>&1 || true
  else
    wp option delete _transient_doing_cron --path=/app/wordpress >/dev/null 2>&1 || true
    wp db query "DELETE FROM wp_options WHERE option_name REGEXP '^_site_transient(_timeout)?_wp_theme_files_patterns-';" --path=/app/wordpress >/dev/null 2>&1 || true
  fi
}

dolt_is_clean() {
  local status_output
  if command -v lando >/dev/null 2>&1; then
    status_output="$(lando dolt -- status)"
    [[ "${status_output}" == *"nothing to commit"* ]]
  else
    [[ "$(wp db query "SELECT COUNT(*) FROM dolt_status;" --skip-column-names --path=/app/wordpress | tr -d '[:space:]')" == "0" ]]
  fi
}

escape_sql() {
  local raw="$1"
  printf '%s' "${raw//\'/\'\'}"
}

message="${1:-}"

if [[ "${message}" == "--help" || "${message}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "${message}" ]]; then
  read -r -p "Save message: " message
fi

if [[ -z "${message}" ]]; then
  echo "Save message is required."
  exit 1
fi

commit_with_hooks="yes"

if command -v lando >/dev/null 2>&1; then
  if lando info >/dev/null 2>&1; then
    cleanup_runtime_noise
    if dolt_is_clean; then
      echo "[save] Dolt is clean, skipping explicit Dolt commit"
    else
      echo "[save] Committing Dolt changes with your message"
      lando dolt -- add -A
      lando dolt -- commit -m "${message}"
    fi
  else
    echo "[save] Lando is not running, skipping explicit Dolt commit"
  fi
else
  if command -v wp >/dev/null 2>&1 && command -v mysql >/dev/null 2>&1; then
    cleanup_runtime_noise
    if dolt_is_clean; then
      echo "[save] Dolt is clean, skipping explicit Dolt commit"
    else
      echo "[save] Committing Dolt changes with your message"
      sql_message="$(escape_sql "${message}")"
      mysql -hdatabase -uroot wordpress -e "CALL DOLT_ADD('-A');"
      mysql -hdatabase -uroot wordpress -e "CALL DOLT_COMMIT('-m','${sql_message}');"
    fi
    # Pre-commit hook depends on host-side lando and should be skipped in container mode.
    commit_with_hooks="no"
  else
    echo "[save] Lando not found, skipping explicit Dolt commit"
  fi
fi

git add -A

if git diff --cached --quiet; then
  echo "[save] No Git changes to commit"
  exit 0
fi

if [[ "${commit_with_hooks}" == "yes" ]]; then
  git commit -m "${message}"
else
  git commit --no-verify -m "${message}"
fi
echo "[save] Saved with commit message: ${message}"
