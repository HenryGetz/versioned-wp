#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_GREEN='\033[32m'
  C_YELLOW='\033[33m'
  C_RED='\033[31m'
  C_CYAN='\033[36m'
  C_BOLD='\033[1m'
else
  C_RESET=''
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
  C_CYAN=''
  C_BOLD=''
fi

section() {
  printf '\n%s%s%s\n' "${C_BOLD}${C_CYAN}" "$1" "${C_RESET}"
}

ok() {
  printf '%b%s%b\n' "${C_GREEN}" "$1" "${C_RESET}"
}

warn() {
  printf '%b%s%b\n' "${C_YELLOW}" "$1" "${C_RESET}"
}

fail() {
  printf '%b%s%b\n' "${C_RED}" "$1" "${C_RESET}"
}

strip_ansi() {
  sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

in_lando_container() {
  [[ -d /app && -f /app/.lando.yml ]]
}

wp_cmd() {
  if command_exists lando; then
    lando wp "$@"
  else
    wp "$@" --path=/app/wordpress
  fi
}

is_lando_running() {
  if ! command_exists lando; then
    in_lando_container
    return $?
  fi

  if ! command_exists jq; then
    return 1
  fi

  local project_name
  local lando_list_json

  project_name="$(lando config --format json 2>/dev/null | jq -r '.landoFileConfig.project // .project // empty')"
  if [[ -z "${project_name}" ]]; then
    return 1
  fi

  lando_list_json="$(lando list --format json 2>/dev/null || true)"
  jq -e --arg project "${project_name}" '
    any(.[]; .app == $project and .running == true)
  ' <<<"${lando_list_json}" >/dev/null 2>&1
}

print_git_section() {
  section "Git"

  local branch
  local last_commit
  local dirty_count
  local upstream
  local ahead
  local behind
  local lr

  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  last_commit="$(git log -1 --pretty=format:'%h %s (%cr)' 2>/dev/null || echo 'no commits')"
  dirty_count="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  echo "Branch: ${branch}"
  echo "Last commit: ${last_commit}"

  if [[ "${dirty_count}" == "0" ]]; then
    ok "Working tree: clean"
  else
    warn "Working tree: dirty (${dirty_count} changed paths)"
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ -n "${upstream}" ]]; then
    lr="$(git rev-list --left-right --count "HEAD...@{upstream}")"
    ahead="$(awk '{print $1}' <<<"${lr}")"
    behind="$(awk '{print $2}' <<<"${lr}")"
    if [[ "${ahead}" == "0" && "${behind}" == "0" ]]; then
      ok "Sync: up to date with ${upstream}"
    else
      warn "Sync: ahead ${ahead}, behind ${behind} (vs ${upstream})"
    fi
  else
    warn "Sync: no upstream configured"
  fi
}

print_dolt_and_wp_section() {
  section "Lando"
  ok "Lando: running"

  section "Dolt"
  local dolt_status
  local dolt_log
  local dolt_count
  local dolt_last_msg
  local dolt_last_date
  local dolt_dirty_count
  local dolt_last_row

  if command_exists lando; then
    dolt_status="$(lando dolt -- status 2>/dev/null || true)"
    if [[ -z "${dolt_status}" ]]; then
      fail "Dolt status: unavailable"
    elif [[ "${dolt_status}" == *"nothing to commit"* ]]; then
      ok "Working set: clean"
    else
      warn "Working set: dirty"
    fi

    dolt_log="$(lando dolt-log 2>/dev/null | strip_ansi || true)"
    dolt_count="$(awk '/^commit / { c++ } END { print c + 0 }' <<<"${dolt_log}")"
    dolt_last_msg="$(awk '/^\t/ { sub(/^\t+/, ""); print; exit }' <<<"${dolt_log}")"
    dolt_last_date="$(awk '/^Date:/ { sub(/^Date:[[:space:]]*/, ""); print; exit }' <<<"${dolt_log}")"
  else
    dolt_dirty_count="$(wp_cmd db query "SELECT COUNT(*) FROM dolt_status;" --skip-column-names 2>/dev/null | tr -d '[:space:]' || echo '')"
    if [[ -z "${dolt_dirty_count}" ]]; then
      fail "Working set: unavailable"
    elif [[ "${dolt_dirty_count}" == "0" ]]; then
      ok "Working set: clean"
    else
      warn "Working set: dirty (${dolt_dirty_count} changed tables)"
    fi

    dolt_count="$(wp_cmd db query "SELECT COUNT(*) FROM dolt_log;" --skip-column-names 2>/dev/null | tr -d '[:space:]' || echo '0')"
    dolt_last_row="$(wp_cmd db query "SELECT message, DATE_FORMAT(date, '%Y-%m-%d %H:%i:%s') FROM dolt_log ORDER BY date DESC LIMIT 1;" --skip-column-names 2>/dev/null || true)"
    dolt_last_msg="$(awk -F $'\t' 'NR==1 { print $1 }' <<<"${dolt_last_row}")"
    dolt_last_date="$(awk -F $'\t' 'NR==1 { print $2 }' <<<"${dolt_last_row}")"
  fi

  echo "Total commits: ${dolt_count}"
  echo "Last commit: ${dolt_last_msg:-unknown}"
  echo "Last commit date: ${dolt_last_date:-unknown}"

  section "WordPress"
  local site_url
  local active_theme
  local page_count
  local post_count
  local plugin_count

  site_url="$(wp_cmd option get siteurl 2>/dev/null || echo 'unknown')"
  active_theme="$(wp_cmd theme list --status=active --field=name 2>/dev/null | head -1 || echo 'unknown')"
  page_count="$(wp_cmd post list --post_type=page --format=count 2>/dev/null || echo 'unknown')"
  post_count="$(wp_cmd post list --post_type=post --format=count 2>/dev/null || echo 'unknown')"
  plugin_count="$(wp_cmd plugin list --status=active --format=count 2>/dev/null || echo 'unknown')"

  echo "Site URL: ${site_url}"
  echo "Active theme: ${active_theme}"
  echo "Page count: ${page_count}"
  echo "Post count: ${post_count}"
  echo "Active plugins: ${plugin_count}"
}

print_lando_stopped_section() {
  section "Lando"
  warn "Lando: stopped"
  warn "[Lando not running — start with: lando start]"

  section "Dolt"
  warn "Skipped because Lando is not running"

  section "WordPress"
  warn "Skipped because Lando is not running"
}

print_staging_section() {
  section "Staging"

  local db_commit
  local staging_head

  db_commit="$(git log -1 --pretty=format:'%h %s (%cr)' -- database/ 2>/dev/null || true)"
  if [[ -n "${db_commit}" ]]; then
    echo "Last DB artifact commit: ${db_commit}"
  else
    warn "Last DB artifact commit: none found"
  fi

  # CHANGEME-staging-url should be your staging hostname (no protocol).
  staging_head="$(curl -sI https://CHANGEME-staging-url 2>/dev/null | head -1 | tr -d '\r' || true)"
  if [[ -n "${staging_head}" ]]; then
    if [[ "${staging_head}" == *"200"* ]]; then
      ok "Staging health: ${staging_head}"
    else
      warn "Staging health: ${staging_head}"
    fi
  else
    fail "Staging health: unreachable"
  fi
}

print_git_section

if is_lando_running; then
  print_dolt_and_wp_section
else
  print_lando_stopped_section
fi

print_staging_section
echo
