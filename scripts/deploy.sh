#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy.sh

Pushes local main to origin/main to trigger staging deploy.
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

branch="$(git rev-parse --abbrev-ref HEAD)"
last_commit="$(git log -1 --pretty=format:'%h %s (%cr)')"
dirty_count="$(git status --porcelain | wc -l | tr -d ' ')"

echo "Deploy summary"
echo "- Branch: ${branch}"
echo "- Last commit: ${last_commit}"

if [[ "${dirty_count}" == "0" ]]; then
  echo "- Working tree: clean"
else
  echo "- Working tree: dirty (${dirty_count} changed paths)"
  read -r -p "Save changes first with scripts/save.sh? [y/N] " should_save
  if [[ "${should_save}" == "y" || "${should_save}" == "Y" ]]; then
    "${ROOT_DIR}/scripts/save.sh"
  else
    read -r -p "Continue deploy without saving local changes? [y/N] " continue_without_save
    if [[ "${continue_without_save}" != "y" && "${continue_without_save}" != "Y" ]]; then
      echo "Deployment canceled."
      exit 1
    fi
  fi
fi

if [[ "${branch}" != "main" ]]; then
  echo "Warning: staging deploys from main only."
  read -r -p "Continue and push origin main anyway? [y/N] " continue_non_main
  if [[ "${continue_non_main}" != "y" && "${continue_non_main}" != "Y" ]]; then
    echo "Deployment canceled."
    exit 1
  fi
fi

echo "Pushing to origin main..."
origin_url="$(git config --get remote.origin.url || true)"
if ! git push origin main; then
  if [[ -n "${origin_url}" && "${origin_url}" =~ ^https://github.com/(.+)\.git$ ]]; then
    ssh_remote="git[@]github.com:${BASH_REMATCH[1]}.git"
    echo "Primary push failed; retrying with SSH remote ${ssh_remote}"
    git push "${ssh_remote}" main
  else
    echo "Push failed and no SSH fallback remote could be derived."
    exit 1
  fi
fi

sleep 2

actions_url=""

if [[ "${origin_url}" =~ ^git[@]github.com:(.+)\.git$ ]]; then
  actions_url="https://github.com/${BASH_REMATCH[1]}/actions"
elif [[ "${origin_url}" =~ ^https://github.com/(.+)\.git$ ]]; then
  actions_url="https://github.com/${BASH_REMATCH[1]}/actions"
fi

if [[ -n "${actions_url}" ]]; then
  echo "Watch deploy at: ${actions_url}"
else
  echo "Watch deploy at: your repository Actions tab"
fi
