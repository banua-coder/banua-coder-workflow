#!/bin/bash
# File Size Check Script
# Checks file sizes against configurable thresholds.
#
# Usage:
#   ./check-file-sizes.sh [options]
#   ./check-file-sizes.sh --dart-max 20KB
#   ./check-file-sizes.sh --asset-max 40KB --format markdown
#
# Options:
#   --dart-max <size>       Max Dart file size (default: 20KB)
#   --asset-max <size>      Max asset file size (default: 40KB)
#   --dir <directory>       Directory to check (default: .)
#   -f, --format <format>   Output format: plain, markdown, github (default: plain)
#   --strict                Exit with error if any file exceeds limit
#   -v, --verbose           Show all files, not just violations
#   -h, --help              Show this help message

set -e

# ============================================
# Configuration
# ============================================

DART_MAX="20KB"
ASSET_MAX="40KB"
CHECK_DIR="."
OUTPUT_FORMAT="plain"
STRICT_MODE=false
VERBOSE=false

# ============================================
# Argument parsing
# ============================================

show_help() {
    cat << EOF
File Size Check Script

Checks file sizes against configurable thresholds for Flutter/Dart projects.

Usage:
  $(basename "$0") [options]

Options:
  --dart-max <size>       Max Dart file size (default: 20KB)
  --asset-max <size>      Max asset file size (default: 40KB)
  --dir <directory>       Directory to check (default: .)
  -f, --format <format>   Output format: plain, markdown, github (default: plain)
  --strict                Exit with error if any file exceeds limit
  -v, --verbose           Show all files, not just violations
  -h, --help              Show this help message

Size Formats:
  Sizes can be specified as: 10KB, 100KB, 1MB, etc.

Examples:
  $(basename "$0") --dart-max 20KB --asset-max 40KB
  $(basename "$0") --dir lib --format markdown
  $(basename "$0") --strict --format github

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --dart-max)
            DART_MAX="$2"
            shift 2
            ;;
        --asset-max)
            ASSET_MAX="$2"
            shift 2
            ;;
        --dir)
            CHECK_DIR="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --strict)
            STRICT_MODE=true
            shift
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

parse_size() {
    local size="$1"
    local value=$(echo "$size" | grep -oE '^[0-9]+')
    local unit=$(echo "$size" | grep -oE '[A-Za-z]+$' | tr '[:lower:]' '[:upper:]')

    case "$unit" in
        KB|K)
            echo $((value * 1024))
            ;;
        MB|M)
            echo $((value * 1024 * 1024))
            ;;
        GB|G)
            echo $((value * 1024 * 1024 * 1024))
            ;;
        B|"")
            echo "$value"
            ;;
        *)
            echo "$value"
            ;;
    esac
}

format_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=1; $bytes / 1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

get_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file" 2>/dev/null
    else
        stat -c%s "$file" 2>/dev/null
    fi
}

# ============================================
# Main
# ============================================

DART_MAX_BYTES=$(parse_size "$DART_MAX")
ASSET_MAX_BYTES=$(parse_size "$ASSET_MAX")

DART_VIOLATIONS=()
ASSET_VIOLATIONS=()
DART_TOTAL=0
ASSET_TOTAL=0

# Check Dart files
while IFS= read -r file; do
    [ -z "$file" ] && continue
    ((DART_TOTAL++))

    SIZE=$(get_file_size "$file")
    if [ "$SIZE" -gt "$DART_MAX_BYTES" ]; then
        DART_VIOLATIONS+=("$file|$SIZE")
    fi
done < <(find "$CHECK_DIR" -name "*.dart" -type f ! -path "*/.*" ! -path "*/.dart_tool/*" 2>/dev/null)

# Check asset files
while IFS= read -r file; do
    [ -z "$file" ] && continue
    ((ASSET_TOTAL++))

    SIZE=$(get_file_size "$file")
    if [ "$SIZE" -gt "$ASSET_MAX_BYTES" ]; then
        ASSET_VIOLATIONS+=("$file|$SIZE")
    fi
done < <(find "$CHECK_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.svg" -o -name "*.gif" -o -name "*.webp" \) ! -path "*/.*" 2>/dev/null)

# Output results
HAS_VIOLATIONS=false
if [ ${#DART_VIOLATIONS[@]} -gt 0 ] || [ ${#ASSET_VIOLATIONS[@]} -gt 0 ]; then
    HAS_VIOLATIONS=true
fi

case "$OUTPUT_FORMAT" in
    markdown)
        echo "## 📏 File Size Check"
        echo ""
        echo "### Dart Files (max: $DART_MAX)"
        echo ""
        if [ ${#DART_VIOLATIONS[@]} -eq 0 ]; then
            echo "✅ All $DART_TOTAL Dart files are within the size limit."
        else
            echo "| File | Size | Status |"
            echo "|------|------|--------|"
            for item in "${DART_VIOLATIONS[@]}"; do
                IFS='|' read -r file size <<< "$item"
                echo "| \`$file\` | $(format_size "$size") | ❌ Exceeds limit |"
            done
            echo ""
            echo "❌ ${#DART_VIOLATIONS[@]} of $DART_TOTAL files exceed the limit"
        fi
        echo ""
        echo "### Asset Files (max: $ASSET_MAX)"
        echo ""
        if [ ${#ASSET_VIOLATIONS[@]} -eq 0 ]; then
            echo "✅ All $ASSET_TOTAL assets are within the size limit."
        else
            echo "| File | Size | Status |"
            echo "|------|------|--------|"
            for item in "${ASSET_VIOLATIONS[@]}"; do
                IFS='|' read -r file size <<< "$item"
                echo "| \`$file\` | $(format_size "$size") | ⚠️ Exceeds limit |"
            done
            echo ""
            echo "⚠️ ${#ASSET_VIOLATIONS[@]} of $ASSET_TOTAL assets exceed the limit"
        fi
        ;;

    github)
        # GitHub Actions annotations
        for item in "${DART_VIOLATIONS[@]}"; do
            IFS='|' read -r file size <<< "$item"
            echo "::error file=$file::Dart file size $(format_size "$size") exceeds maximum of $DART_MAX"
        done
        for item in "${ASSET_VIOLATIONS[@]}"; do
            IFS='|' read -r file size <<< "$item"
            echo "::warning file=$file::Asset size $(format_size "$size") exceeds recommended maximum of $ASSET_MAX"
        done

        if [ ${#DART_VIOLATIONS[@]} -eq 0 ] && [ ${#ASSET_VIOLATIONS[@]} -eq 0 ]; then
            echo "✅ All files are within size limits"
        fi
        ;;

    *)
        # Plain format
        echo "File Size Check Results"
        echo "======================="
        echo ""
        echo "Dart Files (max: $DART_MAX):"
        if [ ${#DART_VIOLATIONS[@]} -eq 0 ]; then
            echo "  ✅ All $DART_TOTAL files OK"
        else
            for item in "${DART_VIOLATIONS[@]}"; do
                IFS='|' read -r file size <<< "$item"
                echo "  ❌ $file ($(format_size "$size"))"
            done
            echo "  ${#DART_VIOLATIONS[@]} of $DART_TOTAL files exceed limit"
        fi
        echo ""
        echo "Asset Files (max: $ASSET_MAX):"
        if [ ${#ASSET_VIOLATIONS[@]} -eq 0 ]; then
            echo "  ✅ All $ASSET_TOTAL files OK"
        else
            for item in "${ASSET_VIOLATIONS[@]}"; do
                IFS='|' read -r file size <<< "$item"
                echo "  ⚠️ $file ($(format_size "$size"))"
            done
            echo "  ${#ASSET_VIOLATIONS[@]} of $ASSET_TOTAL assets exceed limit"
        fi
        ;;
esac

# Exit with error in strict mode if violations found
if [ "$STRICT_MODE" = true ] && [ "$HAS_VIOLATIONS" = true ]; then
    exit 1
fi

exit 0
