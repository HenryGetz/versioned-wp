#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "This will destroy local Dolt DB state and rebuild from the Git-tracked snapshot."
read -r -p "Continue? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Fully tear down local Lando app state to mimic a clean machine.
lando destroy -y >/dev/null 2>&1 || true
rm -rf "${ROOT_DIR}/database/dolt"
mkdir -p "${ROOT_DIR}/database/dolt"
touch "${ROOT_DIR}/database/dolt/.gitkeep"
rm -f "${ROOT_DIR}/wordpress/wp-config.php"

"${ROOT_DIR}/scripts/setup-dev.sh"
