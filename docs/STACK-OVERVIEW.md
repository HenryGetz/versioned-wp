# Stack Overview

This template keeps WordPress code and database state moving together from local development to staging.

## Architecture Diagram

```text
Developer
  |
  | git commit (pre-commit hook)
  v
Local Repo -------------------------------> GitHub (code + DB artifacts)
  |                                          |
  | lando start                              | push to main
  v                                          v
Lando + WordPress + Dolt               GitHub Actions deploy-staging
  |                                          |
  | DB snapshot + Dolt log in git            | rsync code
  |                                          | conditional DB import
  +----------------------------------------->| wp search-replace local->staging
                                             v
                                      Staging WordPress (MySQL)
```

## Components

- Local runtime: Lando runs WordPress and Dolt. WordPress talks to Dolt over MySQL protocol.
- Versioned DB artifacts: `database/snapshots/wordpress-baseline.sql`, `database/snapshots/dolt-log.txt`, and `database/dolt/`.
- Git integration: `.githooks/pre-commit` triggers `scripts/db-sync-github.sh --pre-commit`.
- Deployment: `.github/workflows/deploy-staging.yml` deploys code and optionally imports DB snapshot when DB artifacts changed.
- Verification: Playwright checks in `tests/staging/` validate staging after deploy.

## Environment Boundaries

- Local uses Dolt for database version control.
- Staging/production keep standard MySQL-compatible hosting.
- URL rewriting is handled during deploy/import flows to prevent local URL leakage.
