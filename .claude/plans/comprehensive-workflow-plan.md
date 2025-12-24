# Comprehensive Workflow Plan

## Goal

Make `banua-coder-workflow` a universal, reusable workflow toolkit for ALL project types.

## Target Projects & Requirements

| Project | Type | CI Platform | Special Needs |
|---------|------|-------------|---------------|
| ayana_web | Laravel + Vue | GitHub Actions | PHP tests, Vue lint, asset optimization |
| pico-api-go | Go | GitHub Actions | Go tests, lint, Docker deploy |
| stadata-js | TypeScript | GitHub Actions | NPM publish, bundle size |
| form_gear_engine_sdk | Flutter | GitHub Actions | pub.dev publish, coverage |
| archipelago template | Flutter Monorepo | GitHub + GitLab | Melos, affected packages, multi-coverage |

## Current State

### banua-coder-workflow has

| Workflow | Purpose | Project Types |
|----------|---------|---------------|
| `deploy-on-tag.yml` | Tag-based deployment | Laravel |
| `housekeeping.yml` | PR cleanup, stale issues | All |
| `laravel-tests.yml` | PHP + Vue testing | Laravel |
| `lint.yml` | Code linting | Laravel, Node |
| `publish-dart.yml` | Publish to pub.dev | Flutter/Dart |
| `publish-npm.yml` | Publish to npm | Node.js |
| `publish-php.yml` | Publish to Packagist | PHP |
| `release.yml` | Release automation | All |
| `sanity-check.yml` | Code quality checks | Laravel, Vue, Dart |

### archipelago template has

| Component | Purpose |
|-----------|---------|
| `ci.yml` | Static analysis, tests, coverage |
| `monorepo_toolkit` | CLI for monorepo operations |
| Devtools (Dart) | size-guard, coverage, affected, etc. |

## Gap Analysis

### Missing in banua-coder-workflow

1. **Flutter/Dart CI** - analyze, test, format
2. **Monorepo support** - affected packages detection
3. **Coverage workflow** - with PR comments
4. **Size guard workflow** - file size limits
5. **Go CI** - go test, go vet, golangci-lint
6. **GitLab CI templates** - for GitLab users

### Missing in archipelago template

1. **Release automation** - changelog, version bump
2. **Publish workflows** - pub.dev automation
3. **Deploy workflows** - production deployment

## Proposed Structure

```
banua-coder-workflow/
├── .github/
│   └── workflows/
│       ├── ci-laravel.yml       # Laravel + Vue testing
│       ├── ci-flutter.yml       # Flutter/Dart testing (single + monorepo)
│       ├── ci-go.yml            # Go testing
│       ├── ci-node.yml          # Node.js/TypeScript testing
│       ├── lint.yml             # Universal linting
│       ├── sanity-check.yml     # Code quality checks
│       ├── coverage.yml         # Coverage with PR comments
│       ├── size-guard.yml       # File size limits
│       ├── release.yml          # Release automation
│       ├── deploy-on-tag.yml    # Tag-based deployment
│       ├── publish-dart.yml     # pub.dev publish
│       ├── publish-npm.yml      # npm publish
│       ├── publish-php.yml      # Packagist publish
│       └── housekeeping.yml     # PR/issue cleanup
│
├── .gitlab/                      # GitLab CI templates
│   └── ci/
│       ├── flutter.gitlab-ci.yml
│       ├── laravel.gitlab-ci.yml
│       └── common.gitlab-ci.yml
│
├── scripts/
│   ├── laravel/                  # Laravel sanity checks
│   │   ├── check-missing-requests.php
│   │   ├── check-column-mismatches.php
│   │   └── check-relationship-conflicts.php
│   │
│   ├── vue/                      # Vue/JS checks
│   │   ├── check-native-inputs.cjs
│   │   └── check-vue-types.sh
│   │
│   ├── flutter/                  # Flutter/Dart checks
│   │   ├── check-file-sizes.sh
│   │   └── affected-packages.sh
│   │
│   └── release/                  # Release automation
│       ├── generate-changelog.js # Main changelog generator
│       ├── update-version.sh     # Version updater
│       └── extract-changelog.js  # Changelog section extractor
│
├── actions/                      # Composite actions
│   ├── setup-flutter/
│   │   └── action.yml
│   ├── setup-laravel/
│   │   └── action.yml
│   └── setup-node/
│       └── action.yml
│
└── README.md
```

## Implementation Phases

### Phase 1: Release Scripts (Priority) - COMPLETED

- [x] Add Laravel sanity check scripts
- [x] Add Vue sanity check scripts
- [x] Create `generate-changelog.js` (unified, flexible)
- [x] Create `update-version.sh` (multi-platform, enhanced)
- [x] Create `extract-changelog.js` (utility)

### Phase 2: Flutter/Dart Support

- [ ] Create `ci-flutter.yml` workflow
- [ ] Add affected packages detection script
- [ ] Add size guard script for Dart/assets
- [ ] Create `coverage.yml` with PR comments

### Phase 3: Go Support

- [ ] Create `ci-go.yml` workflow
- [ ] Add Go-specific linting

### Phase 4: Composite Actions

- [ ] Create `setup-flutter` action
- [ ] Create `setup-laravel` action
- [ ] Create `setup-node` action

### Phase 5: GitLab CI Templates

- [ ] Create Flutter GitLab CI template
- [ ] Create Laravel GitLab CI template

## Key Design Decisions

### 1. JavaScript for Release Scripts

Why JavaScript over Ruby:
- Node.js available in all CI runners
- No additional dependencies needed
- Easier to maintain single version

### 2. Monorepo Detection

```javascript
// Auto-detect monorepo
function detectMonorepo() {
  if (fs.existsSync('melos.yaml')) return 'melos';
  if (fs.existsSync('lerna.json')) return 'lerna';
  if (fs.existsSync('pnpm-workspace.yaml')) return 'pnpm';
  if (fs.existsSync('rush.json')) return 'rush';
  return null;
}
```

### 3. Configuration Priority

1. CLI arguments (highest)
2. Config file (`.release-config.yml`)
3. Auto-detection
4. Sensible defaults

### 4. Workflow Inputs Standardization

All workflows should have consistent inputs:
- `project-type`: auto, laravel, flutter, node, go
- `working-directory`: for monorepo packages
- `node-version`, `php-version`, `flutter-version`

## Success Criteria

1. **Flexibility**: Works for all project types without modification
2. **Zero Config**: Sensible defaults work out of the box
3. **Override-able**: Everything can be customized via config/inputs
4. **Monorepo Ready**: First-class support for monorepos
5. **CI Agnostic**: Works on GitHub Actions + GitLab CI
