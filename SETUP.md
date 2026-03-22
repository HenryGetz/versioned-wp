# First-Time Setup

Follow these steps when creating a new project from this template.

## 1. Clone the template and rename the directory

```bash
git clone <template-repo-url> <your-project-slug>
cd <your-project-slug>
```

## 2. Replace all `CHANGEME-` placeholders

Search and replace every placeholder before starting services.

```bash
grep -R "CHANGEME" . --include="*.yml" --include="*.yaml" --include="*.sh" --include="*.md" --include="*.json" --include="*.ts" --include="*.php"
```

### Placeholder Reference

| Placeholder | Replace with | Appears in |
| --- | --- | --- |
| `CHANGEME-project-slug` | Project/repo slug (example: `my-church-site`) | `.lando.yml`, `package.json`, `package-lock.json` |
| `CHANGEME-site-title` | WordPress site title (example: `Grace Community Church`) | `scripts/lando-post-start.sh` |
| `CHANGEME-theme-slug` | Active theme slug (folder name inside `wp-content/themes`) | `tests/staging/site-health.spec.ts` |
| `CHANGEME-dev-name` | Your name for Dolt commits | `.lando.yml`, `scripts/setup-dev.sh`, `package.json` |
| `CHANGEME-dev-email` | Your email for Dolt/WordPress admin defaults | `.lando.yml`, `scripts/lando-post-start.sh`, `scripts/setup-dev.sh`, `package.json` |
| `CHANGEME-local-host` | Local hostname/IP for browser access (example: `127.0.0.1`) | `.lando.yml`, `scripts/lando-post-start.sh` |
| `CHANGEME-local-port` | Local HTTP port (example: `8080`) | `.lando.yml`, `scripts/lando-post-start.sh` |
| `CHANGEME-local-url` | Local URL marker used by tests to detect leaked local links/assets (example: `127.0.0.1:8080`) | `tests/staging/site-health.spec.ts` |
| `CHANGEME-ssh-user` | SSH username for staging host (example: `deploy`) | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-ssh-host` | SSH hostname for staging host (example: `staging.example.com`) | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-remote-path` | Absolute path to remote WordPress project root (example: `/home/deploy/my-site`) | `scripts/pull-staging-db.sh`, `scripts/deploy-staging.sh` |
| `CHANGEME-remote-backup-path` | Absolute remote path where pre-deploy SQL backups are stored (example: `/home/deploy/snapshots`) | `.github/workflows/deploy-staging.yml` |
| `CHANGEME-staging-url` | Staging domain without protocol (example: `staging.example.com`) | `scripts/deploy-staging.sh`, `scripts/status.sh`, `tests/staging/playwright.config.ts`, `tests/staging/site-health.spec.ts` |
| `CHANGEME-production-url` | Production domain without protocol (example: `example.com`) | `SETUP.md` |
| `CHANGEME-github-org` | GitHub owner/org for the new repo | `package.json` |
| `CHANGEME-github-repo` | GitHub repository name for the new repo | `package.json` |

## 3. Run initial developer bootstrap

```bash
./scripts/setup-dev.sh
```

## 4. Start Lando

```bash
lando start
```

## 5. Download WordPress core

```bash
lando wp core download --path=/app/wordpress
```

## 6. Install WordPress

Use your local URL, site title, and email values.

```bash
lando wp core install --url="<your-local-url>" --title="<site-title>" --admin_user=admin --admin_password=admin --admin_email="<your-email>"
```

## 7. Install your theme

Copy your theme into:

```text
wordpress/wp-content/themes/
```

Then activate it:

```bash
lando wp theme activate <your-theme-slug> --path=/app/wordpress
```

## 8. Create the first Dolt commit

```bash
lando dolt -- add -A && lando dolt -- commit -m "Initial baseline"
```

## 9. Configure GitHub Actions secrets

Create these repository secrets:

- `TARGET_HOST`: SSH hostname for staging server.
- `TARGET_USER`: SSH user for staging deploys.
- `TARGET_DIR`: Absolute deploy path on staging server.
- `STAGING_URL`: Full staging URL (example: `https://staging.example.com`).
- `SSH_PRIVATE_KEY`: Private key matching deploy user on staging.

## 10. Push to GitHub and verify first deploy

```bash
git add -A
git commit -m "Initial project setup"
git push -u origin main
```

Watch GitHub Actions and confirm deploy + URL rewrite succeed.

## 11. Run staging health checks

```bash
lando test-staging
```
