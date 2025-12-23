# GitLab CI Templates

Reusable GitLab CI templates for various project types.

## Usage

Include the templates in your `.gitlab-ci.yml`:

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/banua-coder/banua-coder-workflow/main/.gitlab/ci/flutter.gitlab-ci.yml'

stages:
  - test
  - build

# Use the templates
analyze:
  extends: .flutter_analyze

format:
  extends: .flutter_format

test:
  extends: .flutter_test

build_android:
  extends: .flutter_build_android
  only:
    - main
```

## Available Templates

### Flutter (`flutter.gitlab-ci.yml`)

| Job | Description |
|-----|-------------|
| `.flutter_base` | Base setup with Flutter SDK and caching |
| `.flutter_analyze` | Static analysis |
| `.flutter_format` | Format checking |
| `.flutter_test` | Unit tests with coverage |
| `.flutter_build_android` | Android APK build |
| `.flutter_build_ios` | iOS build (requires macOS runner) |
| `.flutter_build_web` | Web build |

**Variables:**
- `FLUTTER_VERSION`: Flutter SDK version (default: `stable`)
- `FLUTTER_CHANNEL`: Flutter channel (default: `stable`)
- `RUN_COVERAGE`: Generate coverage (default: `true`)
- `COVERAGE_THRESHOLD`: Minimum coverage % (default: `0`)
- `MELOS_BOOTSTRAP`: For monorepos (default: `auto`)

### Laravel (`laravel.gitlab-ci.yml`)

| Job | Description |
|-----|-------------|
| `.laravel_base` | Base setup with PHP and Composer |
| `.laravel_lint` | PHP linting (Pint/PHPCS/PHP-CS-Fixer) |
| `.laravel_test` | PHPUnit/Pest tests with coverage |
| `.laravel_frontend` | Frontend build (Node.js) |
| `.laravel_with_mysql` | Base with MySQL service |

**Variables:**
- `PHP_VERSION`: PHP version (default: `8.3`)
- `NODE_VERSION`: Node.js version (default: `20`)
- `RUN_COVERAGE`: Generate coverage (default: `true`)
- `COVERAGE_THRESHOLD`: Minimum coverage % (default: `0`)
- `DB_CONNECTION`: Database type (default: `sqlite`)

### Go (`go.gitlab-ci.yml`)

| Job | Description |
|-----|-------------|
| `.go_base` | Base setup with Go and module caching |
| `.go_lint` | golangci-lint |
| `.go_test` | Tests with coverage |
| `.go_build` | Binary build with optimizations |
| `.go_security` | Security scanning with govulncheck |
| `.go_with_postgres` | Base with PostgreSQL service |
| `.go_with_redis` | Base with Redis service |

**Variables:**
- `GO_VERSION`: Go version (default: `1.22`)
- `RUN_LINT`: Run linting (default: `true`)
- `RUN_COVERAGE`: Generate coverage (default: `true`)
- `COVERAGE_THRESHOLD`: Minimum coverage % (default: `0`)
- `BUILD_TARGET`: Build target path (default: auto-detect)
- `BUILD_OUTPUT`: Output binary name (default: `app`)

### Node.js (`node.gitlab-ci.yml`)

| Job | Description |
|-----|-------------|
| `.node_base` | Base setup with auto-detected package manager |
| `.node_lint` | ESLint/custom linting |
| `.node_typecheck` | TypeScript type checking |
| `.node_test` | Tests with coverage |
| `.node_build` | Production build |
| `.node_monorepo` | Monorepo support (pnpm workspaces, lerna, nx) |
| `.node_publish` | NPM publishing |

**Variables:**
- `NODE_VERSION`: Node.js version (default: `20`)
- `PACKAGE_MANAGER`: Package manager - npm, pnpm, yarn, auto (default: `auto`)
- `RUN_LINT`: Run linting (default: `true`)
- `RUN_TYPECHECK`: Run type checking (default: `true`)
- `RUN_COVERAGE`: Generate coverage (default: `true`)
- `COVERAGE_THRESHOLD`: Minimum coverage % (default: `0`)

## Example Configurations

### Flutter App

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/banua-coder/banua-coder-workflow/main/.gitlab/ci/flutter.gitlab-ci.yml'

variables:
  FLUTTER_VERSION: "3.24.0"
  COVERAGE_THRESHOLD: "80"

stages:
  - test
  - build

analyze:
  extends: .flutter_analyze

format:
  extends: .flutter_format

test:
  extends: .flutter_test

build:
  extends: .flutter_build_android
  only:
    - main
    - tags
```

### Laravel API

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/banua-coder/banua-coder-workflow/main/.gitlab/ci/laravel.gitlab-ci.yml'

variables:
  PHP_VERSION: "8.3"
  COVERAGE_THRESHOLD: "70"

stages:
  - test
  - build

lint:
  extends: .laravel_lint

test:
  extends: .laravel_test
  extends: .laravel_with_mysql
```

### Go Microservice

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/banua-coder/banua-coder-workflow/main/.gitlab/ci/go.gitlab-ci.yml'

variables:
  GO_VERSION: "1.22"
  BUILD_OUTPUT: "myservice"
  COVERAGE_THRESHOLD: "75"

stages:
  - test
  - build

lint:
  extends: .go_lint

test:
  extends: .go_test
  extends: .go_with_postgres

security:
  extends: .go_security

build:
  extends: .go_build
  only:
    - main
    - tags
```

### TypeScript Library

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/banua-coder/banua-coder-workflow/main/.gitlab/ci/node.gitlab-ci.yml'

variables:
  NODE_VERSION: "20"
  PACKAGE_MANAGER: "pnpm"
  COVERAGE_THRESHOLD: "80"

stages:
  - test
  - build
  - deploy

lint:
  extends: .node_lint

typecheck:
  extends: .node_typecheck

test:
  extends: .node_test

build:
  extends: .node_build

publish:
  extends: .node_publish
  only:
    - tags
```
