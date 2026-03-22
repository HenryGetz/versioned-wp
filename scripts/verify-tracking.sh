#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "Verifying repository tracking guarantees..."

if rg -n "dbvc|db-version-control" \
  --glob '!wordpress/wp-includes/certificates/ca-bundle.crt' \
  --glob '!scripts/verify-tracking.sh' \
  --glob '!.github/workflows/verify-db-tracking.yml' \
  .; then
  echo "Legacy DBVC references detected."
  exit 1
fi

test -d database/dolt
test -d database/snapshots

if [[ -f database/snapshots/wordpress-baseline.sql ]]; then
  test -s database/LOCAL_SITEURL
  test -s database/snapshots/wordpress-baseline.sql
  test -s database/snapshots/dolt-log.txt
else
  # Fresh template projects may not have a baseline snapshot yet.
  test -f database/dolt/.gitkeep
  test -f database/snapshots/.gitkeep
fi

test -x scripts/setup-dev.sh
test -x scripts/force-reset-db.sh
test -x scripts/db-sync-github.sh
test -x scripts/db-restore.sh

test -f .github/workflows/deploy-staging.yml
test -f .github/workflows/verify-db-tracking.yml

echo "All tracking guardrails passed."
