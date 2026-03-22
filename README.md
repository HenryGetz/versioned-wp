# WordPress FSE + Dolt Template

This template gives you a production-ready WordPress Full Site Editing workflow with database version control built in: Dolt runs locally inside Lando, database artifacts sync into Git, staging deploys can conditionally import SQL snapshots with URL rewriting, Playwright verifies staging health, and recovery scripts provide fast rollback/reset paths.

## Architecture

- Local development: Lando + WordPress + Dolt (`database/dolt`) as the MySQL-compatible database engine.
- Remote environments: standard MySQL-compatible WordPress hosting on staging/production.
- Deployment model: GitHub Actions deploys files via `rsync`; DB import runs only when tracked DB artifacts change.
- DB tracking model: pre-commit hook runs `scripts/db-sync-github.sh --pre-commit` to keep Dolt + SQL snapshot artifacts synchronized.

## Quick Start

Start with [`SETUP.md`](SETUP.md) and complete the placeholder replacement table before running any scripts.

## Daily Workflow

| Goal | Command |
| --- | --- |
| Check project status | `lando status` |
| Save code + DB checkpoint | `lando save "your message"` |
| Push to staging deploy pipeline | `lando deploy` |
| Pull staging DB into local | `lando pull-db` |
| Run staging Playwright checks | `lando test-staging` |
| Create Dolt commit manually | `lando dolt -- add -A && lando dolt -- commit -m "message"` |
| Inspect Dolt history | `lando dolt-log` |
| Inspect Dolt working diff | `lando dolt-diff` |
| Hard reset local Dolt working state | `lando dolt-reset` |

## Recovery Playbook

### 1) Undo local uncommitted DB changes

```bash
lando dolt-reset
```

### 2) Restore local DB from a previous Git-tracked snapshot

```bash
./scripts/db-restore.sh <git-ref>
```

### 3) Recover staging from a pre-deploy backup

- Each deploy stores a SQL backup under `CHANGEME-remote-backup-path`.
- SSH to staging and import the desired snapshot:

```bash
ssh <user>@<host> "cd <target-dir>/wordpress && wp db import <backup-file>.sql"
```

## Available Scripts

- `scripts/setup-dev.sh`: bootstrap local tooling, hooks, Lando, and baseline checks.
- `scripts/status.sh`: one-screen health summary for Git, Lando, Dolt, WordPress, and staging.
- `scripts/save.sh`: commit Dolt changes (when needed) and Git changes with one message.
- `scripts/deploy.sh`: guarded push helper that triggers the staging GitHub Actions deploy.
- `scripts/test-staging.sh`: run Playwright staging smoke/health checks.
- `scripts/db-sync-github.sh`: sync Dolt + SQL snapshot artifacts into Git.
- `scripts/db-restore.sh`: restore local DB snapshot from a specified Git ref.
- `scripts/pull-staging-db.sh`: import staging DB into local and commit resulting Dolt state.
- `scripts/nuke-local.sh`: destructive local rebuild from tracked snapshot.
- `scripts/force-reset-db.sh`: destructive full reset helper (alternate rebuild path).
- `scripts/deploy-staging.sh`: manual SQL deployment helper for staging.
- `scripts/verify-tracking.sh`: guardrails for required DB-tracking files and repository rules.
- `scripts/lando-post-start.sh`: Lando post-start automation for WP bootstrap/config.
- `scripts/mysqlcheck`: compatibility shim for tooling expecting `mysqlcheck`.

## Included vs You Add

- Included: Lando + Dolt wiring, Git hooks, CI workflows, DB snapshot scripts, Playwright staging checks, recovery tooling, and docs.
- You add: your FSE theme, plugins, content, media, server secrets, and environment-specific URLs/paths.

