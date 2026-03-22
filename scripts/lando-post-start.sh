#!/usr/bin/env bash

set -euo pipefail

WP_PATH="/app/wordpress"
SNAPSHOT_PATH="/app/database/snapshots/wordpress-baseline.sql"
# Replace CHANGEME values in setup:
# - CHANGEME-local-host / CHANGEME-local-port: local URL fallback used at first boot.
# - CHANGEME-site-title: default wp core install title for first-run installs.
# - CHANGEME-dev-email: default admin email for first-run installs.
BASE_HOST="${APP_HTTP_HOST:-CHANGEME-local-host}"
BASE_PORT="${APP_HTTP_PORT:-CHANGEME-local-port}"
BASE_URL="http://${BASE_HOST}:${BASE_PORT}"

ln -sf /app/scripts/mysqlcheck /usr/local/bin/mysqlcheck
ln -sf /app/scripts/mysqlcheck /usr/local/bin/mariadb-check

if [[ ! -f "${WP_PATH}/wp-config.php" ]]; then
  wp config create \
    --dbname=wordpress \
    --dbuser=root \
    --dbpass='' \
    --dbhost=database \
    --skip-check \
    --force \
    --path="${WP_PATH}"
fi

wp config set DISABLE_WP_CRON true --raw --path="${WP_PATH}"

if ! wp core is-installed --path="${WP_PATH}" >/dev/null 2>&1; then
  if [[ -f "${SNAPSHOT_PATH}" ]]; then
    wp db import "${SNAPSHOT_PATH}" --path="${WP_PATH}"
  else
    wp core install \
      --url="${BASE_URL}" \
      --title="CHANGEME-site-title" \
      --admin_user=admin \
      --admin_password=admin \
      --admin_email=CHANGEME-dev-email \
      --skip-email \
      --path="${WP_PATH}"
  fi
fi

if wp core is-installed --path="${WP_PATH}" >/dev/null 2>&1; then
  wp option update home "${BASE_URL}" --path="${WP_PATH}"
  wp option update siteurl "${BASE_URL}" --path="${WP_PATH}"
fi
