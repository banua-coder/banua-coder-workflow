# Banua Coder Workflows

Reusable GitHub Actions workflows for Git Flow release management across multiple project types.

## Features

- 🚀 **Release Management** - Automated release flow with changelog generation
- 🔥 **Hotfix Support** - Quick patch releases with proper versioning
- 📦 **Multi-Platform Publishing** - npm, Dart/Flutter, PHP packages
- 🌐 **Web Deployment** - Deploy to SSH, Vercel, Netlify, Firebase
- 📱 **Mobile Deployment** - Android and iOS Flutter apps
- 🔄 **Back-merge** - Automatic PR to sync changes back to develop

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
| `node-version` | Node.js version | `20` |
| `pnpm-version` | pnpm version (empty = use packageManager from package.json) | `` |
| `php-version` | PHP version | `8.2` |
| `flutter-version` | Flutter version | `3.27.2` |

### `deploy-on-tag.yml`

Deploy when a tag is pushed.

**Inputs:**

| Input | Description | Default |
|-------|-------------|---------|
| `environment` | Deployment environment | `production` |
| `deploy-provider` | Provider: `ssh`, `vercel`, `netlify`, `firebase` | `ssh` |
| `deploy-path` | Deployment path (for SSH) | `/var/www/app` |

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
│     │ v1.0.0  │ ──── Deploy to production                       │
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
| `DEPLOY_HOST` | SSH deployment | Server hostname |
| `DEPLOY_USER` | SSH deployment | SSH username |
| `DEPLOY_KEY` | SSH deployment | SSH private key |
| `VERCEL_TOKEN` | Vercel deployment | Vercel auth token |
| `NETLIFY_AUTH_TOKEN` | Netlify deployment | Netlify auth token |
| `NETLIFY_SITE_ID` | Netlify deployment | Netlify site ID |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase deployment | Firebase service account JSON |

**Note:** For pub.dev publishing, we use OIDC authentication instead of secrets. Configure a GitHub environment named "pub.dev" following [Dart's automated publishing guide](https://dart.dev/tools/pub/automated-publishing).

## License

MIT License - see [LICENSE](./LICENSE) for details.
