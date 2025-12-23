#!/bin/bash
# Affected Packages Detection Script
# Detects which packages in a Flutter monorepo have changed since a base branch.
#
# Usage:
#   ./affected-packages.sh [options]
#   ./affected-packages.sh --base main
#   ./affected-packages.sh --base develop --format json
#
# Options:
#   -b, --base <branch>     Base branch to compare against (default: main)
#   -f, --format <format>   Output format: plain, json, github (default: plain)
#   -d, --dir <directory>   Packages directory (default: packages)
#   -v, --verbose           Show detailed output
#   -h, --help              Show this help message

set -e

# ============================================
# Argument parsing
# ============================================

BASE_BRANCH="main"
OUTPUT_FORMAT="plain"
PACKAGES_DIR="packages"
VERBOSE=false

show_help() {
    cat << EOF
Affected Packages Detection Script

Detects which packages in a Flutter monorepo have changed since a base branch.

Usage:
  $(basename "$0") [options]

Options:
  -b, --base <branch>     Base branch to compare against (default: main)
  -f, --format <format>   Output format: plain, json, github (default: plain)
  -d, --dir <directory>   Packages directory (default: packages)
  -v, --verbose           Show detailed output
  -h, --help              Show this help message

Output Formats:
  plain     One package per line
  json      JSON array of package names
  github    GitHub Actions output format (for use in matrix)

Examples:
  $(basename "$0") --base main
  $(basename "$0") --base develop --format json
  $(basename "$0") --dir packages --verbose

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -d|--dir)
            PACKAGES_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================
# Functions
# ============================================

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1" >&2
    fi
}

detect_packages_directory() {
    # Try common monorepo structures
    if [ -d "packages" ]; then
        echo "packages"
    elif [ -d "apps" ]; then
        echo "apps"
    elif [ -d "modules" ]; then
        echo "modules"
    elif [ -f "melos.yaml" ]; then
        # Parse melos.yaml for packages glob
        grep -A1 "packages:" melos.yaml | tail -1 | sed 's/.*- //' | sed 's/\*\*//' | sed 's/\/$//' || echo "packages"
    else
        echo "packages"
    fi
}

get_changed_files() {
    local base="$1"

    # Try to get merge-base first
    MERGE_BASE=$(git merge-base "$base" HEAD 2>/dev/null || echo "")

    if [ -n "$MERGE_BASE" ]; then
        git diff --name-only "$MERGE_BASE"..HEAD
    else
        # Fallback: compare directly
        git diff --name-only "$base"..HEAD 2>/dev/null || git diff --name-only HEAD~1..HEAD
    fi
}

extract_package_from_path() {
    local file="$1"
    local pkg_dir="$2"

    # Extract package name from file path
    # e.g., packages/core/lib/main.dart -> core
    if [[ "$file" == "$pkg_dir/"* ]]; then
        echo "$file" | sed "s|^$pkg_dir/||" | cut -d'/' -f1
    fi
}

# ============================================
# Main
# ============================================

# Auto-detect packages directory if default doesn't exist
if [ ! -d "$PACKAGES_DIR" ]; then
    PACKAGES_DIR=$(detect_packages_directory)
    log_verbose "Auto-detected packages directory: $PACKAGES_DIR"
fi

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

log_verbose "Base branch: $BASE_BRANCH"
log_verbose "Packages directory: $PACKAGES_DIR"

# Get changed files
CHANGED_FILES=$(get_changed_files "$BASE_BRANCH")

if [ -z "$CHANGED_FILES" ]; then
    log_verbose "No changed files found"
    case "$OUTPUT_FORMAT" in
        json)
            echo "[]"
            ;;
        github)
            echo "packages=[]"
            ;;
        *)
            # Plain format: output nothing
            ;;
    esac
    exit 0
fi

log_verbose "Changed files:"
log_verbose "$CHANGED_FILES"

# Extract affected packages
AFFECTED_PACKAGES=()

while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Check if file is in packages directory
    PKG_NAME=$(extract_package_from_path "$file" "$PACKAGES_DIR")

    if [ -n "$PKG_NAME" ]; then
        # Check if package has pubspec.yaml (is a valid package)
        if [ -f "$PACKAGES_DIR/$PKG_NAME/pubspec.yaml" ]; then
            # Add if not already in list
            if [[ ! " ${AFFECTED_PACKAGES[*]} " =~ " ${PKG_NAME} " ]]; then
                AFFECTED_PACKAGES+=("$PKG_NAME")
                log_verbose "Affected package: $PKG_NAME"
            fi
        fi
    fi

    # Also check for root-level changes that affect all packages
    if [[ "$file" == "pubspec.yaml" ]] || \
       [[ "$file" == "melos.yaml" ]] || \
       [[ "$file" == "analysis_options.yaml" ]]; then
        log_verbose "Root config changed: $file - all packages affected"
        # Mark all packages as affected
        while IFS= read -r pkg_dir; do
            [ -z "$pkg_dir" ] && continue
            PKG_NAME=$(basename "$pkg_dir")
            if [ -f "$pkg_dir/pubspec.yaml" ]; then
                if [[ ! " ${AFFECTED_PACKAGES[*]} " =~ " ${PKG_NAME} " ]]; then
                    AFFECTED_PACKAGES+=("$PKG_NAME")
                fi
            fi
        done < <(find "$PACKAGES_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    fi
done <<< "$CHANGED_FILES"

# Output based on format
case "$OUTPUT_FORMAT" in
    json)
        if [ ${#AFFECTED_PACKAGES[@]} -eq 0 ]; then
            echo "[]"
        else
            printf '['
            for i in "${!AFFECTED_PACKAGES[@]}"; do
                if [ $i -gt 0 ]; then printf ','; fi
                printf '"%s"' "${AFFECTED_PACKAGES[$i]}"
            done
            printf ']\n'
        fi
        ;;
    github)
        if [ ${#AFFECTED_PACKAGES[@]} -eq 0 ]; then
            echo "packages=[]"
        else
            PACKAGES_JSON=$(printf '['
            for i in "${!AFFECTED_PACKAGES[@]}"; do
                if [ $i -gt 0 ]; then printf ','; fi
                printf '"%s"' "${AFFECTED_PACKAGES[$i]}"
            done
            printf ']')
            echo "packages=$PACKAGES_JSON"
        fi
        ;;
    *)
        # Plain format
        for pkg in "${AFFECTED_PACKAGES[@]}"; do
            echo "$pkg"
        done
        ;;
esac

log_verbose "Found ${#AFFECTED_PACKAGES[@]} affected package(s)"
