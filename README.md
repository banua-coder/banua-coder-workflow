# Banua Coder Workflows

Reusable GitHub Actions workflows for Git Flow release management across multiple project types.

## Features

- 🚀 **Release Management** - Automated release flow with changelog generation
- 🔥 **Hotfix Support** - Quick patch releases with proper versioning
- 📦 **Multi-Platform Publishing** - npm, Dart/Flutter, PHP packages
- 🌐 **Web Deployment** - Deploy to SSH, Vercel, Netlify, Firebase
- 📱 **Mobile Deployment** - Android and iOS Flutter apps
- 🔄 **Back-merge** - Automatic PR to sync changes back to develop
- 🧹 **Sanity Checks** - Code quality checks for Vue, Laravel, Dart/Flutter projects
- 🛡️ **Backup & Rollback** - Automatic pre-deployment backup with rollback on failure (SSH)
- 🔍 **Go CI** - Lint, test, coverage, and build for Go projects

## Supported Project Types

| Type | Changelog Strategy | Description |
|------|-------------------|-------------|
| `web-app` | Post-tag | Changelog after tag, included in back-merge |
| `npm-package` | Pre-merge | Changelog before merge, included in published package |
| `dart-package` | Pre-merge | Changelog before merge, included in pub.dev |
| `flutter-package` | Pre-merge | Changelog before merge, included in pub.dev |
| `flutter-app` | Post-tag | Changelog after tag, included in back-merge |
| `php-package` | Pre-merge | Changelog before merge, included in packagist |

## Quick Start

### 1. Create `.github/workflows/release.yml` in your repository

```yaml
name: Release

on:
  push:
    branches:
      - 'release/**'
      - 'hotfix/**'
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  release:
    uses: banua-coder/banua-coder-workflow/.github/workflows/release.yml@v1
    with:
      project-type: web-app  # or: npm-package, dart-package, flutter-package, php-package
      main-branch: main
      develop-branch: develop
    secrets: inherit
```

### 2. Push a release branch

```bash
git checkout develop
git checkout -b release/1.0.0
git push origin release/1.0.0
```

The workflow will:
1. Create a PR to main
2. When merged: tag the release, generate changelog, create back-merge PR

## Workflows

### `ci-go.yml`

Full CI pipeline for Go projects: lint, test with coverage, and build.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `go-version` | Go version | `stable` |
| `working-directory` | Working directory | `.` |
| `run-tests` | Run unit tests | `true` |
| `run-lint` | Run golangci-lint | `true` |
| `run-build` | Build the project | `true` |
| `run-coverage` | Generate coverage report | `true` |
| `test-packages` | Packages to test | `./...` |
| `build-target` | Build target file | auto-detected |
| `build-output` | Build output binary name | `app` |
| `coverage-threshold` | Minimum coverage % (0 = disabled) | `0` |
| `golangci-lint-version` | golangci-lint version | `v1.61.0` |
| `post-coverage-comment` | Post coverage as PR comment | `true` |
| `run-vulncheck` | Run the [vulnerability scan](#vulnerability-scanning) | `true` |
| `vulncheck-severity-threshold` | Fail the scan at or above this severity | `high` |
| `vulncheck-ignore-ids` | Advisories to ignore, one `<id> <reason>` per line | `` |

> **Note:** golangci-lint v2.x requires `golangci-lint-version: v2.x.x` — the action uses `golangci-lint-action@v7` which supports v2.

**Example:**

```yaml
jobs:
  ci:
    uses: banua-coder/banua-coder-workflow/.github/workflows/ci-go.yml@v1
    with:
      go-version: '1.24.x'
      golangci-lint-version: 'v2.10.1'
      coverage-threshold: 80
    secrets: inherit
```

### `release.yml`

Main release workflow that handles the entire release process.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `project-type` | Project type: `web-app`, `npm-package`, `dart-package`, `flutter-package`, `flutter-app`, `php-package` | `web-app` |
| `main-branch` | Main/production branch name | `main` |
| `develop-branch` | Development branch name | `develop` |
| `changelog-format` | Changelog format: `keepachangelog`, `conventional`, `simple` | `keepachangelog` |
| `auto-merge-backport` | Auto-merge back-merge PR | `false` |
| `tag-prefix` | Prefix for the release tag. Use `v` when the registry only accepts `v{{version}}` tags (pub.dev automated publishing) | `''` |
| `node-version` | Node.js version | `20` |
| `pnpm-version` | pnpm version (empty = use packageManager from package.json) | `` |
| `php-version` | PHP version | `8.2` |
| `flutter-version` | Flutter version | `3.27.2` |

### `deploy-on-tag.yml`

Deploy when a tag is pushed. Supports **backup & automatic rollback** for SSH deployments.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `environment` | Deployment environment | `production` |
| `deploy-provider` | Provider: `ssh`, `vercel`, `netlify`, `firebase` | `ssh` |
| `build-command` | Custom build command | `` |
| `deploy-path` | Deployment path on server (SSH) | `` |
| `node-version` | Node.js version | `20` |
| `php-version` | PHP version | `8.2` |
| `backup-enabled` | Take a backup before deploying (SSH only) | `true` |
| `backup-keep` | Number of backups to retain (0 = keep all) | `3` |

**Outputs:**

| Output | Description |
|--------|-------------|
| `deploy-url` | Deployment URL (Vercel/Netlify) |
| `status` | Deployment status |
| `backup-path` | Path to the pre-deployment backup on the server |

**Backup & Rollback Flow (SSH):**

```
┌─────────────────────────────────────────────────────────────────┐
│                   DEPLOY WITH BACKUP/ROLLBACK                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Backup job                                                  │
│     Copy current deploy-path → .backups/<timestamp>_<app>      │
│     Prune old backups (keep N most recent)                      │
│          │                                                      │
│          ▼                                                      │
│  2. Deploy job (on backup success)                              │
│     git pull + composer/npm + artisan optimize                  │
│          │                                                      │
│          ├── success ──▶ done ✅                                 │
│          │                                                      │
│          └── failure ──▶ Rollback job 🔄                        │
│                          rm broken deploy-path                  │
│                          cp backup → deploy-path                │
│                          artisan optimize (if Laravel)          │
│                          mark workflow as failed ❌              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> **Cloud providers** (Vercel, Netlify, Firebase) manage their own versioning and instant rollback — the backup step is skipped automatically for these providers.

**Example:**

```yaml
name: Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    uses: banua-coder/banua-coder-workflow/.github/workflows/deploy-on-tag.yml@v1
    with:
      environment: production
      deploy-provider: ssh
      deploy-path: /var/www/my-app
      backup-enabled: true
      backup-keep: 3
    secrets: inherit
```

### `housekeeping.yml`

Automatically delete merged branches (except protected ones).

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `protected-branches` | Comma-separated list of protected branches | `main,master,develop` |

### `lint.yml`

Run code linting (PHP with Pint, frontend with ESLint/Prettier).

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `php-version` | PHP version | `8.3` |
| `node-version` | Node.js version | `20` |
| `pnpm-version` | pnpm version (empty = use packageManager) | `` |
| `lint-php` | Run PHP linting | `true` |
| `lint-frontend` | Run frontend linting | `true` |

### `laravel-tests.yml`

Run Laravel/PHP tests with database setup.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `php-version` | PHP version | `8.3` |
| `node-version` | Node.js version | `20` |
| `pnpm-version` | pnpm version (empty = use packageManager) | `` |
| `database` | Database type: `sqlite`, `mysql`, `pgsql` | `sqlite` |
| `run-migrations` | Run database migrations | `true` |
| `run-seeders` | Run database seeders | `true` |
| `build-assets` | Build frontend assets | `true` |
| `test-command` | Test command to run | `./vendor/bin/pest` |
| `coverage` | Code coverage: `xdebug`, `pcov`, `none` | `none` |

### `sanity-check.yml`

Customizable code quality and sanity checks for multiple project types.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `project-type` | Project type: `laravel`, `vue`, `react`, `dart`, `flutter`, `auto` | `auto` |
| `php-version` | PHP version | `8.3` |
| `node-version` | Node.js version | `20` |
| `flutter-version` | Flutter version | `3.38.4` |
| `vue-max-loc` | Max lines of code for Vue files | `700` |
| `check-native-inputs` | Check for native HTML inputs (should use shadcn/ui) | `true` |
| `check-vue-types` | Check for type definitions inside .vue files | `true` |
| `check-missing-requests` | Check for missing FormRequest classes | `true` |
| `check-column-mismatches` | Check for column name mismatches | `true` |
| `check-relationship-conflicts` | Check for property/relationship name conflicts | `true` |
| `dart-max-file-size` | Max Dart file size in KB | `18` |
| `dart-max-loc` | Max lines of code for Dart files | `600` |
| `check-assets` | Check for non-optimized assets | `true` |

**Check Categories:**

- **Vue/JS**: File size limits, native input detection, type definitions in .vue files
- **Laravel**: FormRequest usage, column mismatches, relationship conflicts
- **Dart/Flutter**: File size and LOC limits
- **Assets**: Image optimization (JPEG, PNG, SVG)

### `publish-npm.yml`

Publish package to npm registry.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `node-version` | Node.js version | `20` |
| `registry` | npm registry URL | `https://registry.npmjs.org` |
| `access` | Package access level | `public` |
| `dry-run` | Perform dry run | `false` |

### `publish-dart.yml`

Publish package to pub.dev using OIDC authentication.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `flutter-version` | Flutter version | `3.27.2` |
| `use-flutter` | Use Flutter SDK | `true` |
| `dry-run` | Perform dry run | `false` |
| `environment` | GitHub environment for OIDC auth | `pub.dev` |

**Note:** This workflow uses OIDC authentication instead of PUB_CREDENTIALS. You need to configure a GitHub environment named "pub.dev" in your repository settings. See [Dart Automated Publishing](https://dart.dev/tools/pub/automated-publishing) for setup instructions.

### `publish-php.yml`

Notify Packagist about new release.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `php-version` | PHP version | `8.2` |

## Vulnerability scanning

`vulncheck.yml` scans the dependencies of a project for known vulnerabilities. A known vulnerability is a published advisory (a GHSA, CVE, or GO id) that affects a version you use. The workflow runs in one job on one runner. It installs only the tools for the languages it finds.

The workflows `ci-go.yml`, `ci-node.yml`, `ci-flutter.yml`, `ci-laravel.yml`, and `ci-rust.yml` call it as a separate job named `vulncheck`. That job runs in parallel with the other jobs and never blocks them. To turn it off, set `run-vulncheck: false`.

### Usage in a CI workflow

```yaml
jobs:
  ci:
    uses: banua-coder/banua-coder-workflow/.github/workflows/ci-go.yml@v1
    with:
      run-vulncheck: true               # default
      vulncheck-severity-threshold: high # default
      vulncheck-ignore-ids: |
        GHSA-xxxx-xxxx-xxxx not reachable, used only in tests, review by 2026-12-01
```

The CI workflows pass only `run-vulncheck`, `vulncheck-severity-threshold`, and `vulncheck-ignore-ids`. For the other inputs, call `vulncheck.yml` directly.

### Direct usage

```yaml
jobs:
  vulncheck:
    uses: banua-coder/banua-coder-workflow/.github/workflows/vulncheck.yml@v1
    with:
      languages: auto
      working-directory: backend
```

If you want the scan to skip when no dependency file changed, give the caller workflow `pull-requests: read` permission. Without it, the skip check cannot read the changed files. The scan then always runs, which is safe.

### Inputs of `vulncheck.yml`

| Input | Description | Default |
|-------|-------------|---------|
| `languages` | Comma-separated list of `go`, `node`, `dart`, `php`, `rust`, or `auto` | `auto` |
| `working-directory` | Directory of the project | `.` |
| `severity-threshold` | Fail at or above this severity: `low`, `medium`, `high`, `critical` | `high` |
| `fail-on-findings` | `false` reports findings and does not fail the job | `true` |
| `ignore-ids` | Allowlist, one `<advisory-id> <reason>` per line | `` |
| `include-dev-dependencies` | Also scan development dependencies (Node and PHP) | `false` |
| `only-on-dependency-change` | On push and pull_request, skip unless a manifest or lockfile changed | `true` |
| `go-version` | Go version used by govulncheck | `stable` |
| `pnpm-version` | pnpm version, used when `pnpm-lock.yaml` is found | `10` |
| `govulncheck-version` | govulncheck version | `v1.9.0` |
| `osv-scanner-version` | osv-scanner version | `v2.7.0` |
| `cargo-audit-version` | cargo-audit version | `v0.22.2` |

With `languages: auto`, the workflow looks in `working-directory` for `go.mod`, `package.json`, `pubspec.yaml`, `composer.json`, and `Cargo.toml`. It then looks for the lockfile in that directory and in each parent directory up to the repository root. This finds workspace lockfiles. A language without a lockfile is skipped with a notice, because a scan without a lockfile checks no exact versions.

### Languages and tools

| Language | Lockfile | Tool | Reachability |
|----------|----------|------|--------------|
| Go | `go.mod` | `govulncheck` | Yes |
| Node | `pnpm-lock.yaml` | `pnpm audit` | No |
| Node | `package-lock.json` | `npm audit` | No |
| Node | `yarn.lock` | `yarn npm audit` (Yarn 2+) or `yarn audit` (Yarn 1) | No |
| Dart and Flutter | `pubspec.lock` | `osv-scanner` | No |
| PHP and Laravel | `composer.lock` | `composer audit` | No |
| Rust | `Cargo.lock` | `cargo audit` | No |

Bun (`bun.lockb`) is not supported. The workflow skips it with a notice.

`pnpm audit` checks the whole workspace lockfile. In a pnpm workspace, a scan of one package reports the advisories of every package in the workspace.

### Step summary

The job writes a table to the step summary. It has one row per finding with these columns: language, id, package, affected version, fixed version, severity, reachable, and status. The status is one of `blocking`, `below threshold`, `not reachable`, or `ignored`. The table shows the first 100 rows.

### Severity policy

A finding blocks the job when all of these are true:

1. It is not on the `ignore-ids` list.
2. It is not marked unreachable.
3. Its severity is at or above `severity-threshold`.

A finding with an unknown severity blocks at every threshold. `cargo audit` gives a CVSS vector and no score, so all Rust findings have unknown severity. The numeric scores from `osv-scanner` map to critical (9.0 or more), high (7.0 or more), medium (4.0 or more), and low.

Go is different. `govulncheck` reports whether your code calls the vulnerable function. A finding that your code can reach blocks at every threshold. A finding in a module you only import is shown as `not reachable` and does not block. `govulncheck` gives no severity, so `severity-threshold` does not apply to Go.

A scan error also fails the job when `fail-on-findings` is `true`. A scan that did not run must not look like a clean scan.

### Ignore policy

Use `ignore-ids` only when a finding is a false positive or you cannot fix it yet. Write one entry per line. Each entry is the advisory id, a space, and a reason:

```yaml
ignore-ids: |
  GHSA-xxxx-xxxx-xxxx dev-only path, no network input, review by 2026-12-01
  GO-2026-0000 fix needs a major upgrade, tracked in the team backlog
```

The reason is required. An entry without a reason fails the job. State why the finding is safe or when you will fix it. The entry matches the advisory id or any alias, such as a CVE id. The step summary lists every ignored entry with its reason. Lines that start with `#` are comments.

### Weekly schedule

A reusable workflow cannot schedule itself. The `schedule` trigger must be in the workflow of the caller. Copy [`examples/vulncheck-schedule.yml`](./examples/vulncheck-schedule.yml) to your repository. The scheduled run always scans, because the skip check applies only to push and pull_request events. This is how new advisories show up for code that did not change.

### Design decision

Problem: `govulncheck` found five reachable HTTP/2 vulnerabilities in `golang.org/x/net`, and CI did not catch them, because nothing scanned dependencies. GitHub Actions minutes cost money, so the scan must be cheap.

Alternatives:

| Option | Benefit | Cost |
|--------|---------|------|
| A. One `osv-scanner` pass over the whole repository | One tool, one job, all languages | No reachability, so Go reports every vulnerable module, including code you never call. Noisy. |
| B. One job per language | Parallel, isolated logs | Each job pays for a runner start, a checkout, and a cache restore. A project with three languages pays three times. |
| C. One job, native tool per language, `osv-scanner` only for Dart (chosen) | One runner start and one checkout. Uses the best tool for each ecosystem. | The job steps run in sequence. Several tools to keep pinned. |

Why C: the native tools know their ecosystem best, and `govulncheck` is the only option that removes the unreachable noise. `pubspec.lock` has no native audit, so Dart uses `osv-scanner`. The sequential cost is small, because most projects have one or two languages and each scan takes seconds once the tools are cached.

Why not a broader `osv-scanner` pass on top of C: it repeats the findings of the native tools under different ids, it adds a second table to read, and it has no reachability data. Add it later if a language needs coverage that the native tool lacks.

How the cost stays low:

1. The skip check runs before the checkout and uses the GitHub API. A push that changes no manifest or lockfile ends in seconds. The job still bills one minute at minimum.
2. Tool versions are pinned and the binaries are cached by version. `osv-scanner` is checked against its published checksum.
3. There is no matrix.
4. Go uses the `setup-go` module cache. Node uses the native audit and needs no install step, because the audit reads the lockfile only.

Risks and limits:

1. The skip check looks at manifests and lockfiles only. A code change that starts to call a vulnerable function is found by the next scheduled run, not by the push.
2. The CI workflows call `vulncheck.yml@v1`. Move the `v1` tag when you release a change to the scan.
3. Yarn, Composer, and Cargo scans parse JSON from the tools. The tools can change their output format. Pinned tool versions and the "scan error fails the job" rule limit the damage.

## Composite Actions

### `actions/bump-version`

Bump version in project files.

```yaml
- uses: banua-coder/banua-coder-workflow/actions/bump-version@v1
  with:
    version: '1.2.3'
    commit: 'true'
```

### `actions/changelog`

Generate changelog from commits.

```yaml
- uses: banua-coder/banua-coder-workflow/actions/changelog@v1
  with:
    version: '1.2.3'
    format: 'keepachangelog'
```

### `actions/back-merge`

Create back-merge PR to develop.

```yaml
- uses: banua-coder/banua-coder-workflow/actions/back-merge@v1
  with:
    source-branch: 'main'
    target-branch: 'develop'
```

### `actions/setup-environment`

Setup project environment (Node.js, PHP, Flutter).

```yaml
- uses: banua-coder/banua-coder-workflow/actions/setup-environment@v1
  with:
    node-version: '20'
    php-version: '8.2'
```

## Examples

See the [`examples/`](./examples) directory for complete workflow examples:

- [`web-app.yml`](./examples/web-app.yml) - Generic web applications
- [`laravel-app.yml`](./examples/laravel-app.yml) - Laravel application with tests
- [`npm-package.yml`](./examples/npm-package.yml) - npm packages
- [`dart-package.yml`](./examples/dart-package.yml) - Pure Dart packages
- [`flutter-package.yml`](./examples/flutter-package.yml) - Flutter packages
- [`flutter-app.yml`](./examples/flutter-app.yml) - Flutter mobile applications
- [`php-package.yml`](./examples/php-package.yml) - PHP/Composer packages
- [`vulncheck-schedule.yml`](./examples/vulncheck-schedule.yml) - Weekly vulnerability scan

## Release Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        RELEASE FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Create release branch                                       │
│     ┌─────────┐                                                 │
│     │ develop │ ──── git checkout -b release/1.0.0              │
│     └─────────┘                                                 │
│          │                                                      │
│          ▼                                                      │
│  2. Push triggers workflow                                      │
│     ┌───────────────┐                                           │
│     │ release/1.0.0 │ ──── Creates PR to main                   │
│     └───────────────┘                                           │
│          │                                                      │
│          ▼                                                      │
│  3. PR merged to main                                           │
│     ┌──────┐                                                    │
│     │ main │ ──── Tag v1.0.0 created                            │
│     └──────┘      Changelog generated                           │
│          │        Back-merge PR created                         │
│          │                                                      │
│          ▼                                                      │
│  4. Tag triggers deploy/publish                                 │
│     ┌─────────┐                                                 │
│     │ v1.0.0  │ ──── Backup → Deploy → (Rollback on failure)    │
│     └─────────┘      Publish to registry                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Hotfix Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOTFIX FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Create hotfix branch from main                              │
│     ┌──────┐                                                    │
│     │ main │ ──── git checkout -b hotfix/1.0.1                  │
│     └──────┘                                                    │
│          │                                                      │
│          ▼                                                      │
│  2. Push triggers workflow                                      │
│     ┌─────────────┐                                             │
│     │ hotfix/1.0.1│ ──── Creates PR to main                     │
│     └─────────────┘                                             │
│          │                                                      │
│          ▼                                                      │
│  3. PR merged (same as release flow)                            │
│     Tag, changelog, back-merge, deploy                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Conventional Commits

This workflow uses conventional commits to generate changelogs:

| Prefix | Description | Changelog Section |
|--------|-------------|-------------------|
| `feat:` | New feature | Added |
| `fix:` | Bug fix | Fixed |
| `docs:` | Documentation | Documentation |
| `refactor:` | Code refactoring | Changed |
| `perf:` | Performance improvement | Performance |
| `test:` | Adding tests | Tests |
| `chore:` | Maintenance | Maintenance |
| `style:` | Code style | Style |
| `ci:` | CI/CD changes | CI/CD |
| `build:` | Build system | Build |
| `revert:` | Revert changes | Reverted |

## Required Secrets

Configure these secrets in your repository settings:

| Secret | Required For | Description |
|--------|--------------|-------------|
| `GITHUB_TOKEN` | All | Automatically provided by GitHub |
| `NPM_TOKEN` | npm publishing | npm auth token from npmjs.com |
| `SSH_HOST` | SSH deployment | Server hostname |
| `SSH_USER` | SSH deployment | SSH username |
| `SSH_KEY` | SSH deployment | SSH private key |
| `SSH_PORT` | SSH deployment | SSH port (optional, defaults to 22) |
| `VERCEL_TOKEN` | Vercel deployment | Vercel auth token |
| `VERCEL_ORG_ID` | Vercel deployment | Vercel org ID |
| `VERCEL_PROJECT_ID` | Vercel deployment | Vercel project ID |
| `NETLIFY_AUTH_TOKEN` | Netlify deployment | Netlify auth token |
| `NETLIFY_SITE_ID` | Netlify deployment | Netlify site ID |
| `FIREBASE_TOKEN` | Firebase deployment | Firebase service account JSON |

**Note:** For pub.dev publishing, we use OIDC authentication instead of secrets. Configure a GitHub environment named "pub.dev" following [Dart's automated publishing guide](https://dart.dev/tools/pub/automated-publishing).

## License

MIT License - see [LICENSE](./LICENSE) for details.
