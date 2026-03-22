# Scripts Reference

This file documents every executable in `scripts/`.

## `setup-dev.sh`

- Purpose: bootstrap a fresh local environment.
- Usage: `./scripts/setup-dev.sh`
- What it does: configures Git hooks path, starts Lando, checks Dolt/WP readiness, configures Dolt identity, applies runtime-noise cleanup, and verifies baseline state.
- Safety warnings: non-destructive to Git history; may initialize/update local runtime state.

## `status.sh`

- Purpose: one-screen project dashboard.
- Usage: `./scripts/status.sh` or `lando status`
- What it does: reports Git, Dolt, Lando, WordPress, and staging health summary with color output when TTY is available.
- Safety warnings: read-only.

## `save.sh`

- Purpose: save a coherent checkpoint of DB and code work.
- Usage: `./scripts/save.sh "Your message"`
- What it does: commits Dolt changes if dirty, stages Git changes, then commits Git with the same message.
- Safety warnings: creates commits; does not push.

## `deploy.sh`

- Purpose: guided push-to-staging helper.
- Usage: `./scripts/deploy.sh` or `lando deploy`
- What it does: shows branch/commit/dirty summary, prompts if unsaved changes exist, then pushes `main` and prints GitHub Actions URL.
- Safety warnings: pushes to remote; staging deploy automation will run after push.

## `test-staging.sh`

- Purpose: run automated staging browser checks.
- Usage: `./scripts/test-staging.sh` or `lando test-staging`
- What it does: runs Playwright tests in `tests/staging/` with list reporter.
- Safety warnings: read-only against staging URLs; does not SSH or mutate server files.

## `db-sync-github.sh`

- Purpose: sync database artifacts into Git.
- Usage: `./scripts/db-sync-github.sh "Describe DB change"`
- What it does: commits pending Dolt changes, exports SQL snapshot and Dolt log artifact, updates `database/LOCAL_SITEURL`, stages DB files, and commits in manual mode.
- Safety warnings: creates commits; pre-commit mode (`--pre-commit`) is invoked by Git hook and should not be edited casually.

## `db-restore.sh`

- Purpose: restore local DB to the SQL snapshot stored at a specific Git ref.
- Usage: `./scripts/db-restore.sh <git-ref>`
- What it does: exports a safety backup, extracts snapshot from target ref, imports it, then syncs Dolt state with a restore commit.
- Safety warnings: overwrites local DB; backup is written to `database/snapshots/pre-restore-backup.sql`.

## `pull-staging-db.sh`

- Purpose: import current staging DB into local.
- Usage: `./scripts/pull-staging-db.sh`
- What it does: exports staging DB over SSH, backs up local DB, imports staging dump locally, rewrites URLs back to local site URL, commits Dolt state.
- Safety warnings: destructive to local DB content; requires typing `yes` confirmation.

## `nuke-local.sh`

- Purpose: fully rebuild local environment from tracked snapshot.
- Usage: `./scripts/nuke-local.sh`
- What it does: destroys and restarts local runtime, imports `database/snapshots/wordpress-baseline.sql`, syncs Dolt, and runs final checks.
- Safety warnings: destructive local reset; requires typing `yes` confirmation.

## `force-reset-db.sh`

- Purpose: alternate destructive reset helper for local DB/runtime.
- Usage: `./scripts/force-reset-db.sh`
- What it does: performs destructive local reset flow (`lando destroy -y`) then rebuild/setup.
- Safety warnings: destructive local operation.

## `deploy-staging.sh`

- Purpose: manual SQL deploy helper to staging.
- Usage: `./scripts/deploy-staging.sh`
- What it does: exports local DB, rewrites local URL to staging URL, uploads SQL, imports remotely, runs serialized-safe search-replace.
- Safety warnings: writes to staging DB; requires `STAGING_SSH` and `STAGING_PATH` to be configured in the script.

## `verify-tracking.sh`

- Purpose: enforce DB tracking guardrails locally.
- Usage: `./scripts/verify-tracking.sh`
- What it does: validates required tracked artifacts and blocks legacy/invalid DB tracking patterns.
- Safety warnings: read-only checks.

## `lando-post-start.sh`

- Purpose: post-start automation hook.
- Usage: invoked automatically by `.lando.yml` `post-start` event.
- What it does: applies post-start app tasks so local runtime is ready.
- Safety warnings: runs on every `lando start`.

## `mysqlcheck`

- Purpose: compatibility shim for tools expecting `mysqlcheck`.
- Usage: internal utility, typically not called directly.
- What it does: normalizes mysqlcheck behavior in this stack.
- Safety warnings: operational helper; avoid editing unless compatibility behavior changes are required.
