# Contributing

Thanks for helping improve `versioned-wp`.

## Report Bugs

Open a GitHub issue and include:

- what happened
- what you expected
- exact steps to reproduce
- environment details (OS, Docker version, Lando version, Dolt version)

## Suggest Features

Open a GitHub issue describing:

- what you want to add or change
- why it is useful
- alternatives you considered

## Contribute Code

1. Fork the repository.
2. Create a branch for your change.
3. Make your edits and include docs updates when behavior changes.
4. Open a pull request with a clear summary and testing notes.

## Quality Bar

Changes should preserve the template's full end-to-end workflow:

- local bootstrap with Lando + Dolt
- WordPress install and DB tracking
- pre-commit DB sync behavior
- restore/recovery workflows
- staging Playwright health checks

When possible, include command output from your validation steps in the pull request description.
