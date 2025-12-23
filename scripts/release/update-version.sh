#!/bin/bash
# Version Update Script
# Updates version in specified files based on configuration or defaults
#
# Usage:
#   ./update-version.sh <version> [options]
#   ./update-version.sh 1.2.3
#   ./update-version.sh v1.2.3 --dry-run
#   ./update-version.sh 1.2.3 --config .version-config.yml --tag
#
# Options:
#   -c, --config <file>   Config file (default: .version-config.yml)
#   -d, --dry-run         Preview changes without modifying files
#   -t, --tag             Create git tag after updating version
#   -v, --verbose         Show detailed output
#   -h, --help            Show this help message

set -e

# ============================================
# Argument parsing
# ============================================

VERSION=""
CONFIG_FILE=".version-config.yml"
DRY_RUN=false
CREATE_TAG=false
VERBOSE=false

show_help() {
    cat << EOF
Version Update Script - Universal version updater for all project types

Usage:
  $(basename "$0") <version> [options]

Arguments:
  <version>             Version to set (e.g., 1.2.3 or v1.2.3)

Options:
  -c, --config <file>   Config file (default: .version-config.yml)
  -d, --dry-run         Preview changes without modifying files
  -t, --tag             Create git tag after updating version
  -v, --verbose         Show detailed output
  -h, --help            Show this help message

Supported file types:
  - package.json        (Node.js/JavaScript)
  - pubspec.yaml        (Dart/Flutter)
  - composer.json       (PHP/Laravel)
  - config/app.php      (Laravel)
  - go.mod              (Go)
  - Cargo.toml          (Rust)
  - pyproject.toml      (Python)
  - setup.py            (Python)
  - VERSION             (Generic)
  - version.txt         (Generic)

Examples:
  $(basename "$0") 1.2.3
  $(basename "$0") v2.0.0 --dry-run --verbose
  $(basename "$0") 1.0.0 --config release.yml --tag

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -t|--tag)
            CREATE_TAG=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "Error: Version is required"
    echo ""
    show_help
    exit 1
fi

# Remove 'v' prefix if present
CLEAN_VERSION=$(echo "$VERSION" | sed 's/^v//')
MAJOR_VERSION=$(echo "$CLEAN_VERSION" | cut -d. -f1)
MINOR_VERSION=$(echo "$CLEAN_VERSION" | cut -d. -f2)
PATCH_VERSION=$(echo "$CLEAN_VERSION" | cut -d. -f3)

# ============================================
# Logging functions
# ============================================

log_info() {
    echo "$1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "  $1"
    fi
}

log_dry_run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $1"
    fi
}

# ============================================
# File update functions
# ============================================

update_file() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    local description="${4:-$file}"

    if [ ! -f "$file" ]; then
        log_verbose "File $file not found, skipping"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would update $description"
        log_verbose "  Pattern: $pattern"
        log_verbose "  Replacement: $replacement"
        return 0
    fi

    if command -v perl >/dev/null 2>&1; then
        perl -i -pe "s|$pattern|$replacement|g" "$file"
    else
        # Fallback to sed (macOS compatible with '')
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|$pattern|$replacement|g" "$file"
        else
            sed -i "s|$pattern|$replacement|g" "$file"
        fi
    fi

    log_info "✅ Updated $description"
    return 0
}

if [ "$DRY_RUN" = true ]; then
    log_info "🔍 DRY-RUN: Previewing version update to $CLEAN_VERSION"
else
    log_info "🚀 Updating version to $CLEAN_VERSION"
fi
log_verbose "Major: $MAJOR_VERSION, Minor: $MINOR_VERSION, Patch: $PATCH_VERSION"

# Function to process file updates from config
process_file_update() {
    if [ -z "$CURRENT_FILE" ] || [ -z "$CURRENT_PATTERN" ] || [ -z "$CURRENT_REPLACEMENT" ]; then
        return
    fi

    # Check if file exists
    if [ ! -f "$CURRENT_FILE" ]; then
        log_verbose "File $CURRENT_FILE not found, skipping"
        return
    fi

    # Check 'when' condition
    if [ -n "$CURRENT_WHEN" ]; then
        if [[ "$CURRENT_WHEN" == "major_version_only" ]]; then
            log_verbose "Skipping $CURRENT_FILE (major version only)"
            return
        fi
    fi

    # Prepare replacement string
    REPLACEMENT="$CURRENT_REPLACEMENT"
    REPLACEMENT="${REPLACEMENT//\{version\}/$CLEAN_VERSION}"
    REPLACEMENT="${REPLACEMENT//\{major\}/$MAJOR_VERSION}"
    REPLACEMENT="${REPLACEMENT//\{minor\}/$MINOR_VERSION}"
    REPLACEMENT="${REPLACEMENT//\{patch\}/$PATCH_VERSION}"

    update_file "$CURRENT_FILE" "$CURRENT_PATTERN" "$REPLACEMENT"
}

# Function to update common file types
update_default_files() {
    local updated=0

    # package.json (Node.js/JavaScript)
    if [ -f "package.json" ]; then
        update_file "package.json" \
            "\"version\":[[:space:]]*\"[^\"]*\"" \
            "\"version\": \"$CLEAN_VERSION\"" \
            "package.json (Node.js)" && ((updated++))
    fi

    # pubspec.yaml (Dart/Flutter)
    if [ -f "pubspec.yaml" ]; then
        update_file "pubspec.yaml" \
            "^version:[[:space:]]*[^[:space:]]+" \
            "version: $CLEAN_VERSION" \
            "pubspec.yaml (Flutter)" && ((updated++))
    fi

    # composer.json (PHP)
    if [ -f "composer.json" ]; then
        update_file "composer.json" \
            "\"version\":[[:space:]]*\"[^\"]*\"" \
            "\"version\": \"$CLEAN_VERSION\"" \
            "composer.json (PHP)" && ((updated++))
    fi

    # config/app.php (Laravel)
    if [ -f "config/app.php" ]; then
        if grep -q "env('APP_VERSION'" config/app.php 2>/dev/null; then
            update_file "config/app.php" \
                "env\('APP_VERSION',[[:space:]]*'[^']*'\)" \
                "env('APP_VERSION', '$CLEAN_VERSION')" \
                "config/app.php (Laravel)" && ((updated++))
        elif grep -q "'version'" config/app.php 2>/dev/null; then
            update_file "config/app.php" \
                "'version'[[:space:]]*=>[[:space:]]*'[^']*'" \
                "'version' => '$CLEAN_VERSION'" \
                "config/app.php (Laravel)" && ((updated++))
        fi
    fi

    # go.mod (Go)
    if [ -f "go.mod" ]; then
        # Go modules don't typically have version in go.mod
        # but we can update a version.go file if it exists
        if [ -f "version.go" ]; then
            update_file "version.go" \
                "const[[:space:]]+Version[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
                "const Version = \"$CLEAN_VERSION\"" \
                "version.go (Go)" && ((updated++))
        fi
        # Also check for internal/version/version.go
        if [ -f "internal/version/version.go" ]; then
            update_file "internal/version/version.go" \
                "const[[:space:]]+Version[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
                "const Version = \"$CLEAN_VERSION\"" \
                "internal/version/version.go (Go)" && ((updated++))
        fi
        # Or pkg/version/version.go
        if [ -f "pkg/version/version.go" ]; then
            update_file "pkg/version/version.go" \
                "const[[:space:]]+Version[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
                "const Version = \"$CLEAN_VERSION\"" \
                "pkg/version/version.go (Go)" && ((updated++))
        fi
    fi

    # Cargo.toml (Rust)
    if [ -f "Cargo.toml" ]; then
        update_file "Cargo.toml" \
            "^version[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
            "version = \"$CLEAN_VERSION\"" \
            "Cargo.toml (Rust)" && ((updated++))
    fi

    # pyproject.toml (Python - modern)
    if [ -f "pyproject.toml" ]; then
        update_file "pyproject.toml" \
            "^version[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
            "version = \"$CLEAN_VERSION\"" \
            "pyproject.toml (Python)" && ((updated++))
    fi

    # setup.py (Python - legacy)
    if [ -f "setup.py" ]; then
        update_file "setup.py" \
            "version=[[:space:]]*['\"][^'\"]*['\"]" \
            "version='$CLEAN_VERSION'" \
            "setup.py (Python)" && ((updated++))
    fi

    # build.gradle (Android/Java)
    if [ -f "build.gradle" ]; then
        update_file "build.gradle" \
            "versionName[[:space:]]*['\"][^'\"]*['\"]" \
            "versionName '$CLEAN_VERSION'" \
            "build.gradle (Android)" && ((updated++))
    fi

    # build.gradle.kts (Kotlin DSL)
    if [ -f "build.gradle.kts" ]; then
        update_file "build.gradle.kts" \
            "versionName[[:space:]]*=[[:space:]]*\"[^\"]*\"" \
            "versionName = \"$CLEAN_VERSION\"" \
            "build.gradle.kts (Android/Kotlin)" && ((updated++))
    fi

    # version.txt
    if [ -f "version.txt" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would update version.txt"
        else
            echo "$CLEAN_VERSION" > version.txt
            log_info "✅ Updated version.txt"
        fi
        ((updated++))
    fi

    # VERSION file
    if [ -f "VERSION" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would update VERSION"
        else
            echo "$CLEAN_VERSION" > VERSION
            log_info "✅ Updated VERSION"
        fi
        ((updated++))
    fi

    return $updated
}

# ============================================
# Main execution
# ============================================

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_verbose "Config file $CONFIG_FILE not found, using auto-detection"
    update_default_files
else
    log_verbose "Using config file: $CONFIG_FILE"

    # Read version_files from YAML config
    IN_VERSION_FILES=false
    CURRENT_FILE=""
    CURRENT_PATTERN=""
    CURRENT_REPLACEMENT=""
    CURRENT_WHEN=""

    while IFS= read -r line; do
        # Check if we're entering the version_files section
        if [[ "$line" =~ ^version_files: ]]; then
            IN_VERSION_FILES=true
            continue
        fi

        # Check if we're leaving the version_files section
        if [[ "$IN_VERSION_FILES" == true && "$line" =~ ^[a-zA-Z] ]]; then
            IN_VERSION_FILES=false
            break
        fi

        if [[ "$IN_VERSION_FILES" == true ]]; then
            # Parse YAML entries
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*\"(.*)\" ]]; then
                # Process previous file if we have one
                if [ -n "$CURRENT_FILE" ]; then
                    process_file_update
                fi

                CURRENT_FILE="${BASH_REMATCH[1]}"
                CURRENT_PATTERN=""
                CURRENT_REPLACEMENT=""
                CURRENT_WHEN=""
            elif [[ "$line" =~ ^[[:space:]]*pattern:[[:space:]]*\"(.*)\" ]] || [[ "$line" =~ ^[[:space:]]*pattern:[[:space:]]*\'(.*)\' ]]; then
                CURRENT_PATTERN="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*replacement:[[:space:]]*\"(.*)\" ]] || [[ "$line" =~ ^[[:space:]]*replacement:[[:space:]]*\'(.*)\' ]]; then
                CURRENT_REPLACEMENT="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*when:[[:space:]]*\"(.*)\" ]] || [[ "$line" =~ ^[[:space:]]*when:[[:space:]]*\'(.*)\' ]]; then
                CURRENT_WHEN="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$CONFIG_FILE"

    # Process the last file
    if [ -n "$CURRENT_FILE" ]; then
        process_file_update
    fi
fi

# ============================================
# Git tag creation (optional)
# ============================================

if [ "$CREATE_TAG" = true ]; then
    TAG_NAME="v$CLEAN_VERSION"

    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would create git tag: $TAG_NAME"
    else
        # Check if tag already exists
        if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
            log_info "⚠️  Tag $TAG_NAME already exists, skipping"
        else
            git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
            log_info "🏷️  Created git tag: $TAG_NAME"
        fi
    fi
fi

# ============================================
# Summary
# ============================================

if [ "$DRY_RUN" = true ]; then
    log_info ""
    log_info "🔍 DRY-RUN complete. No files were modified."
else
    log_info ""
    log_info "✅ Version update completed!"
fi
