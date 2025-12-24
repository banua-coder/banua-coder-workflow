# Release Scripts Merger Plan

## Overview

Create comprehensive, flexible release scripts that work across ALL project types:
- **Laravel + Vue** (ayana_web)
- **Go** (pico-api-go)
- **TypeScript/JavaScript** (stadata-js)
- **Flutter single package** (form_gear_engine_sdk)
- **Flutter Monorepo** (archipelago template)

Sources to merge:
- **pico-api-go** (Ruby changelog generator)
- **stadata-js** (JavaScript changelog generator)
- **form_gear_engine_sdk** (Workflow-based changelog generation)
- **archipelago template_base/devtools** (Dart CLI tools for monorepo)

## Flexibility Requirements

### 1. Project Type Detection
Scripts must auto-detect and support:
- `composer.json` → Laravel/PHP
- `package.json` → Node.js/TypeScript/Vue
- `pubspec.yaml` → Dart/Flutter
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pyproject.toml` / `setup.py` → Python

### 2. Monorepo Support
For Flutter monorepos (melos):
- Detect `melos.yaml` presence
- Find all `pubspec.yaml` files in packages
- Option to update all packages or specific ones
- Generate per-package changelogs OR unified changelog

### 3. Configuration File
Support `.changelog.yml` or `.release-config.yml`:
```yaml
# Project type (auto-detected if not specified)
project_type: auto  # auto | laravel | flutter | node | go | rust | python

# Monorepo settings
monorepo:
  enabled: auto  # auto | true | false
  packages_dir: ["packages", "apps", "shared"]
  unified_changelog: false  # Single CHANGELOG.md or per-package

# Changelog format
changelog:
  format: emoji  # emoji | plain
  commit_links: full  # full | short | none
  include_breaking_changes: true
  include_key_highlights: true
  categories:
    feat: "✨ Features"
    fix: "🐛 Bug Fixes"
    docs: "📚 Documentation"
    # ... customizable

# Version files to update
version_files:
  - path: "pubspec.yaml"
    pattern: "version: .*"
    replacement: "version: {version}"
  - path: "lib/src/version.dart"
    pattern: "const packageVersion = '.*'"
    replacement: "const packageVersion = '{version}'"
  - path: "config/app.php"
    pattern: "env\\('APP_VERSION', '.*'\\)"
    replacement: "env('APP_VERSION', '{version}')"
```

### 4. CLI Flexibility
```bash
# Auto-detect everything
./generate-changelog.js

# Specify version
./generate-changelog.js --version 1.2.3

# Override format
./generate-changelog.js --format plain --links short

# Monorepo: specific package
./generate-changelog.js --package core

# Dry run
./generate-changelog.js --dry-run

# Use config file
./generate-changelog.js --config .release-config.yml
```

### 5. Language Agnostic
Primary script in JavaScript (Node.js available in all CI)
But also provide:
- Bash wrapper for simple use cases
- Optional Ruby version for existing pico-api-go compatibility

## Comparison Summary

### Changelog Generators

| Feature | pico-api-go (Ruby) | stadata-js (JS) | form_gear_engine_sdk |
|---------|-------------------|-----------------|---------------------|
| Language | Ruby | JavaScript | Bash (in workflow) |
| Commit Links | Full GitHub URL | Short hash only | Short hash only |
| Emoji Categories | No | Yes | Yes |
| CLI Options | --dry-run, --force, --debug, --version | --version only | N/A (workflow) |
| [Unreleased] Section | Yes | Yes | No |
| Key Highlights | No | No | Yes (auto-detected) |
| Platform Updates | No | No | Yes |
| Dependencies Section | No | No | Yes |
| Breaking Changes | Yes | No | Yes |
| Environment Validation | Yes | No | No |
| Auto-create CHANGELOG | Yes | Yes | Yes |

### Resulting CHANGELOG Format

**pico-api-go style:**
```markdown
## [v2.4.0] - 2025-09-15

### Added
- Configure deploy workflow ([1d362189](https://github.com/repo/commit/1d362189...))

### Fixed
- Fix generate changelog script ([9ab39f0f](https://github.com/repo/commit/9ab39f0f...))
```

**stadata-js/form_gear style:**
```markdown
## [0.4.0] - 2025-11-15

### ✨ Features
- add universal structured data transformation ([4b0281d])

### 🐛 Bug Fixes
- add missing properties to Variable entity ([e9e1d5d])
```

## Decision: Create Two Scripts

### 1. `generate-changelog.rb` (Enhanced Ruby version)

Based on pico-api-go with enhancements:

**Keep from pico-api-go:**
- Class-based architecture
- CLI with options (--dry-run, --force, --debug, --version, --no-links)
- Environment validation
- Full GitHub commit links
- [Unreleased] section support
- Breaking changes detection

**Add from others:**
- [ ] Optional emoji mode (`--emoji` flag)
- [ ] Key Highlights section (auto-detected from commit keywords)
- [ ] Dependencies section for package managers
- [ ] Platform Updates section
- [ ] Extract changelog section utility method

**Categories (configurable):**
```ruby
# With emoji mode
'feat' => { category: 'Added', emoji: '✨' },
'fix' => { category: 'Fixed', emoji: '🐛' },
'docs' => { category: 'Documentation', emoji: '📚' },
...

# Without emoji mode
'feat' => { category: 'Added' },
'fix' => { category: 'Fixed' },
...
```

### 2. `generate-changelog.js` (Enhanced JavaScript version)

For Node.js projects that prefer JavaScript:

**Keep from stadata-js:**
- Simple structure
- Emoji categories
- Extract section utility

**Add from others:**
- [ ] CLI options (--dry-run, --force, --version, --no-emoji, --links)
- [ ] Full GitHub commit links option
- [ ] Breaking changes detection
- [ ] Environment validation (optional)
- [ ] Key Highlights section
- [ ] Dependencies section

### 3. `update-version.sh` (Enhanced Bash version)

Enhanced from pico-api-go with:

**Keep:**
- Config file support (`.version-config.yml`)
- Default file updates (package.json, pubspec.yaml, composer.json, config/app.php)
- Perl/sed fallback

**Add:**
- [ ] Support for build.gradle (Android)
- [ ] Support for Cargo.toml (Rust)
- [ ] Support for setup.py / pyproject.toml (Python)
- [ ] Support for VERSION file
- [ ] Dry-run mode
- [ ] Git tag creation option

### 4. `extract-changelog-section.js`

Copy from stadata-js as utility for workflows.

## Implementation Plan

### Phase 1: Enhanced Ruby Generator
- [ ] Copy existing generate-changelog.rb
- [ ] Add `--emoji` flag for emoji categories
- [ ] Add Key Highlights auto-detection
- [ ] Add Platform Updates section detection
- [ ] Add Dependencies section
- [ ] Update help text and examples

### Phase 2: Enhanced JavaScript Generator
- [ ] Copy existing generate-changelog.js
- [ ] Add CLI argument parsing
- [ ] Add full GitHub commit links option
- [ ] Add breaking changes detection
- [ ] Add Key Highlights section
- [ ] Add environment validation

### Phase 3: Enhanced Version Updater
- [ ] Copy existing update-version.sh
- [ ] Add more file type support
- [ ] Add dry-run mode
- [ ] Add verbose output

### Phase 4: Utility Scripts
- [ ] Copy extract-changelog-section.js

## File Structure

```
scripts/release/
├── generate-changelog.rb       # Ruby version (enhanced from pico-api-go)
├── generate-changelog.js       # JavaScript version (enhanced from stadata-js)
├── update-version.sh           # Version updater (enhanced from pico-api-go)
└── extract-changelog-section.js # Utility (from stadata-js)
```

## Configuration

Both generators will support a `.changelog-config.yml` file:

```yaml
# Optional configuration file
format:
  emoji: true              # Use emoji prefixes
  commit_links: true       # Include GitHub commit links
  full_links: false        # Use full URL vs short hash

categories:
  - feat: Added
  - fix: Fixed
  - docs: Documentation
  # ... custom mappings

highlights:
  keywords:
    - interceptor: "HTTP Interceptor Support"
    - webview: "WebView Integration"
    # ... auto-detect highlights from keywords

sections:
  breaking_changes: true
  key_highlights: true
  dependencies: true
  platform_updates: true
```

## Success Criteria

1. Ruby script supports both emoji and plain text modes
2. JavaScript script has full CLI support
3. Both scripts produce consistent output format
4. Version updater supports all common package managers
5. All scripts work independently (no external dependencies except system tools)
6. Comprehensive help text and usage examples
