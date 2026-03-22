# versioned-wp

WordPress development with real database version control. Every commit captures your code and your database as one atomic snapshot.

## The Problem

WordPress stores pages, menus, widgets, settings, and theme configuration in MySQL, but most teams only version their code in Git. That split causes drift, fragile deploys, and painful environment sync work. Many WordPress developers have lost content changes or broken data migrations because database state was not versioned with code.

## The Solution

This template runs WordPress on Dolt inside Lando for local development. Dolt is MySQL wire-compatible, so WordPress works as usual, but you gain Git-style history for your data: commit, log, diff, branch, and reset. A single `git clone` gives you a full workflow: code + database tracking + deployment automation + recovery tooling.

## What's Included

- Dolt database engine in Lando (MySQL-compatible, WordPress works without code changes)
- Pre-commit hook that auto-syncs DB state into every Git commit
- Staging deploy pipeline via GitHub Actions (conditional DB import, dynamic URL rewrite)
- Recovery scripts (rollback to any commit, fresh-clone rebuild, staging restore)
- Playwright staging health tests
- Developer shortcuts: `lando status`, `lando save`, `lando deploy`, `lando test-staging`

## Quick Start

```bash
git clone https://github.com/HenryGetz/versioned-wp my-project
cd my-project
# Fill in CHANGEME- placeholders (see SETUP.md)
./scripts/setup-dev.sh
lando start
# Start building — your database is version controlled
```

## Requirements

- Docker + Lando
- Git
- Node.js 18+ (for Playwright tests)
- A staging server with SSH access and WP-CLI

## Documentation

- Full setup guide: [`SETUP.md`](SETUP.md)
- Architecture and stack overview: [`docs/STACK-OVERVIEW.md`](docs/STACK-OVERVIEW.md)
- Scripts reference: [`scripts/README.md`](scripts/README.md)

## Daily Workflow

| Goal | Command |
| --- | --- |
| Check local project + DB health | `lando status` |
| Save code and DB together | `lando save "message"` |
| Push to `main` with deploy guardrails | `lando deploy` |
| Run staging browser tests | `lando test-staging` |
| Pull staging DB into local | `lando pull-db` |
| Manual Dolt commit | `lando dolt -- add -A && lando dolt -- commit -m "message"` |
| View Dolt history | `lando dolt-log` |
| View Dolt diff | `lando dolt-diff` |
| Hard reset local Dolt working state | `lando dolt-reset` |

## Recovery Playbook

| Scenario | Command |
| --- | --- |
| Undo uncommitted local DB changes | `lando dolt-reset` |
| Restore DB from a prior Git commit | `./scripts/db-restore.sh <git-ref>` |
| Rebuild local from tracked snapshot | `./scripts/nuke-local.sh` |

## How It Works

- Local: Dolt in Lando replaces MySQL, and WordPress connects the same way it would to MySQL.
- Git: the pre-commit hook runs `scripts/db-sync-github.sh --pre-commit` and captures DB artifacts with your code changes.
- Deploy: GitHub Actions deploys files via `rsync`, imports DB snapshot only when DB artifacts changed, then rewrites URLs for staging.
- Staging and production: standard MySQL WordPress hosting. Dolt is local-only.

See [`docs/STACK-OVERVIEW.md`](docs/STACK-OVERVIEW.md) for the architecture diagram and flow.

## Contributing

Contributions are welcome. Fork the repo, create a branch, and open a pull request.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide.

## License

MIT. See [`LICENSE`](LICENSE).

## Credits

- [Dolt by DoltHub](https://github.com/dolthub/dolt)
- [Lando documentation](https://docs.lando.dev/)
