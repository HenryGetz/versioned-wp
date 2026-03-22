# Setup Guide

Use this guide when starting a brand-new project from `versioned-wp`.

## Prerequisites

- Docker and Lando installed and working.
- Git installed.
- Node.js 18+ and npm installed.
- SSH access to your staging host.
- WP-CLI available on your staging host.

## 1) Clone the template

```bash
git clone https://github.com/HenryGetz/versioned-wp <your-project-slug>
cd <your-project-slug>
```

Verify:

```bash
git rev-parse --show-toplevel
```

## 2) Replace every `CHANGEME-` placeholder

Replace all placeholders before you run local services.

```bash
grep -R "CHANGEME" . --exclude-dir=.git --exclude-dir=node_modules
```

Use this table as your replacement checklist.

| Placeholder | What to set | Example value | Files |
| --- | --- | --- | --- |
| `CHANGEME-project-slug` | Repository/app slug | `my-wordpress-site` | `.lando.yml`, `package.json`, `package-lock.json` |
| `CHANGEME-site-title` | WordPress site title used during first install | `My WordPress Site` | `scripts/lando-post-start.sh` |
| `CHANGEME-theme-slug` | Active theme slug used by tests/scripts | `twentytwentyfive` | `tests/staging/site-health.spec.ts` |
| `CHANGEME-dev-name` | Your name for Dolt commit identity | `Jane Developer` | `.lando.yml`, `scripts/setup-dev.sh`, `package.json` |
| `CHANGEME-dev-email` | Your email for Dolt/admin defaults | `jane@example.com` | `.lando.yml`, `scripts/lando-post-start.sh`, `scripts/setup-dev.sh`, `package.json` |
| `CHANGEME-local-host` | Local host/IP where site is served | `127.0.0.1` | `.lando.yml`, `scripts/lando-post-start.sh` |
| `CHANGEME-local-port` | Local HTTP port | `8080` | `.lando.yml`, `scripts/lando-post-start.sh` |
| `CHANGEME-local-url` | Local URL marker for leak detection in tests | `127.0.0.1:8080` | `tests/staging/site-health.spec.ts` |
| `CHANGEME-ssh-user` | SSH username for staging server | `deploy` | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-ssh-host` | SSH host for staging server | `staging.example.com` | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-remote-path` | Absolute remote project path | `/home/deploy/my-wordpress-site` | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-remote-backup-path` | Absolute remote SQL backup directory | `/home/deploy/snapshots` | `.github/workflows/deploy-staging.yml` |
| `CHANGEME-staging-url` | Staging domain (no protocol in script placeholders) | `staging.example.com` | `scripts/deploy-staging.sh`, `scripts/status.sh`, `tests/staging/playwright.config.ts`, `tests/staging/site-health.spec.ts` |
| `CHANGEME-production-url` | Production domain for documentation and ops notes | `example.com` | `SETUP.md` |
| `CHANGEME-github-org` | GitHub org/user that owns the repo | `my-org` | `package.json` |
| `CHANGEME-github-repo` | GitHub repository name | `my-wordpress-site` | `package.json` |

Verify no placeholders remain:

```bash
grep -R "CHANGEME" . --exclude-dir=.git --exclude-dir=node_modules
```

## 3) Install Node dependencies

```bash
npm ci
```

Verify:

```bash
npx playwright --version
```

## 4) Run developer bootstrap

```bash
./scripts/setup-dev.sh
```

Verify hooks path and setup result:

```bash
git config --get core.hooksPath
```

Expected output: `.githooks`

## 5) Start Lando

```bash
lando start
```

Verify services are running:

```bash
lando info
```

## 6) Ensure WordPress is installed

If core files are missing:

```bash
lando wp core download --path=/app/wordpress
```

If `wp-config.php` is missing:

```bash
lando wp config create --dbname=wordpress --dbuser=root --dbpass="" --dbhost=database --path=/app/wordpress
```

If WordPress is not installed yet:

```bash
lando wp core install --url="http://<local-host>:<local-port>" --title="<site-title>" --admin_user=admin --admin_password=admin --admin_email="<your-email>" --path=/app/wordpress
```

Verify:

```bash
lando wp option get siteurl --path=/app/wordpress
```

## 7) Choose and activate your theme

WordPress core ships with `twentytwentyfive` by default. You can keep it or install any FSE theme.

If using a custom theme:

```text
wordpress/wp-content/themes/
```

Then activate it:

```bash
lando wp theme activate <your-theme-slug> --path=/app/wordpress
```

Note: `CHANGEME-theme-slug` matters only where scripts/tests assert the active theme name.

Verify active theme:

```bash
lando wp theme list --status=active --field=name --path=/app/wordpress
```

## 8) Create your first Dolt baseline commit

```bash
lando dolt -- add -A
lando dolt -- commit -m "Initial baseline"
```

Verify Dolt history:

```bash
lando dolt-log
```

## 9) Configure GitHub Actions secrets

This template's deploy workflow requires these repository secrets:

- `TARGET_HOST`
- `TARGET_USER`
- `TARGET_DIR`
- `STAGING_URL`
- `SSH_PRIVATE_KEY`

`TARGET_DIR`, `CHANGEME-remote-path`, and `CHANGEME-remote-backup-path` should be adjusted for your hosting provider and directory layout.

Optional verification (requires GitHub CLI auth):

```bash
gh secret list
```

## 10) Push to GitHub and verify first deploy

```bash
git add -A
git commit -m "Initial project setup"
git branch -M main
git push -u origin main
```

Verify in GitHub Actions:

- The `Deploy to Staging` workflow starts.
- `Deploy via Rsync` succeeds.
- If DB artifacts changed, `Sync Database and Fix URLs` succeeds.

## 11) Run staging health checks

```bash
lando test-staging
```

Verify:

- Playwright exits with code `0`.
- No local URL leakage errors are reported.
- Screenshots are written to `tests/staging/screenshots/`.
