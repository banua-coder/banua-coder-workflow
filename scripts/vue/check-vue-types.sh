#!/bin/bash

# Script to detect interface/type definitions inside Vue files
# These should be moved to dedicated .ts files in the types directory
# Exception: Props interfaces defined inline with defineProps are allowed
#
# Usage: ./scripts/check-vue-types.sh [vue-directory]

VUE_DIR="${1:-resources/js}"

# Files to exclude from checking (use relative paths from project root)
# Add files here that have legitimate local interfaces/types
EXCLUDED_FILES=(
    # Example: "resources/js/pages/SomeFile.vue"
)

# Type/interface names to exclude (these are allowed inline)
# Local type aliases that reference imported types are fine
EXCLUDED_TYPES=(
    "type Recommendation ="
    "type StatusKey ="
    "type Template ="
)

# Function to check if file should be excluded
is_file_excluded() {
    local file="$1"
    for excluded in "${EXCLUDED_FILES[@]}"; do
        if [[ "$file" == *"$excluded"* ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if type/interface name should be excluded
is_type_excluded() {
    local name="$1"
    for excluded in "${EXCLUDED_TYPES[@]}"; do
        if [[ "$name" == *"$excluded"* ]]; then
            return 0
        fi
    done
    return 1
}

echo "Checking for interface/type definitions in Vue files..."
echo "(Props interfaces for defineProps are excluded)"
if [ ${#EXCLUDED_FILES[@]} -gt 0 ]; then
    echo "(${#EXCLUDED_FILES[@]} file(s) excluded)"
fi
if [ ${#EXCLUDED_TYPES[@]} -gt 0 ]; then
    echo "(${#EXCLUDED_TYPES[@]} type(s) excluded)"
fi
echo ""

found_issues=0
files_with_issues=""

# Find all Vue files and check for interface/type definitions
while IFS= read -r file; do
    # Skip excluded files
    if is_file_excluded "$file"; then
        continue
    fi
    # Extract script content between <script> tags
    script_content=$(sed -n '/<script/,/<\/script>/p' "$file" 2>/dev/null)

    # Check for interface definitions (excluding Props pattern and imports)
    # Match lines that start with "interface" or "export interface" but not "Props"
    raw_interfaces=$(echo "$script_content" | grep -n "^interface \|^export interface " | grep -v "Props")

    # Check for type definitions (excluding imports, type assertions, and common patterns)
    raw_types=$(echo "$script_content" | grep -n "^type \|^export type ")

    # Filter out excluded types/interfaces
    interfaces=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        excluded=false
        for excl in "${EXCLUDED_TYPES[@]}"; do
            if [[ "$line" == *"$excl"* ]]; then
                excluded=true
                break
            fi
        done
        if [ "$excluded" = false ]; then
            interfaces="${interfaces}${line}\n"
        fi
    done <<< "$raw_interfaces"
    interfaces=$(echo -e "$interfaces" | sed '/^$/d')

    types=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        excluded=false
        for excl in "${EXCLUDED_TYPES[@]}"; do
            if [[ "$line" == *"$excl"* ]]; then
                excluded=true
                break
            fi
        done
        if [ "$excluded" = false ]; then
            types="${types}${line}\n"
        fi
    done <<< "$raw_types"
    types=$(echo -e "$types" | sed '/^$/d')

    if [ -n "$interfaces" ] || [ -n "$types" ]; then
        echo "Found in: $file"

        if [ -n "$interfaces" ]; then
            echo "  Interfaces:"
            echo -e "$interfaces" | while read -r line; do
                [ -n "$line" ] && echo "    $line"
            done
        fi

        if [ -n "$types" ]; then
            echo "  Types:"
            echo -e "$types" | while read -r line; do
                [ -n "$line" ] && echo "    $line"
            done
        fi

        echo ""
        found_issues=$((found_issues + 1))
        files_with_issues="$files_with_issues\n  - $file"
    fi
done < <(find "$VUE_DIR" -name "*.vue" -type f 2>/dev/null)

if [ $found_issues -eq 0 ]; then
    echo "✅ No interface/type definitions found in Vue files."
    exit 0
else
    echo "❌ Found issues in $found_issues file(s)."
    echo ""
    echo "Please move these definitions to the types/ directory."
    echo "Then import them in the Vue file."
    exit 1
fi
