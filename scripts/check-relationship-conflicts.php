<?php

/**
 * Relationship-Column Conflict Detector
 *
 * Detects when an Eloquent model has both:
 * 1. A column/attribute in $fillable
 * 2. A relationship method with the same name
 *
 * This causes bugs because Laravel's attribute access takes precedence over
 * relationship methods, so $model->notes returns the column value instead
 * of calling notes() relationship.
 *
 * Usage: php scripts/check-relationship-conflicts.php
 */
$modelsDir = __DIR__.'/../app/Models';
$conflicts = [];
$warnings = [];

if (! is_dir($modelsDir)) {
    echo "Error: Models directory not found at $modelsDir\n";
    exit(1);
}

$modelFiles = glob($modelsDir.'/*.php');

foreach ($modelFiles as $file) {
    $content = file_get_contents($file);
    $className = basename($file, '.php');

    // Extract fillable columns
    $fillableColumns = extractFillableColumns($content);

    // Extract relationship method names
    $relationshipMethods = extractRelationshipMethods($content);

    // Check for conflicts
    foreach ($fillableColumns as $column) {
        if (in_array($column, $relationshipMethods)) {
            $conflicts[] = [
                'model' => $className,
                'file' => $file,
                'name' => $column,
                'type' => 'CONFLICT',
                'message' => "Column '$column' in \$fillable conflicts with relationship method '$column()'",
            ];
        }
    }

    // Extract casts columns (also act as attributes)
    $castsColumns = extractCastsColumns($content);

    foreach ($castsColumns as $column) {
        if (in_array($column, $relationshipMethods)) {
            $conflicts[] = [
                'model' => $className,
                'file' => $file,
                'name' => $column,
                'type' => 'CONFLICT',
                'message' => "Cast '$column' in casts() conflicts with relationship method '$column()'",
            ];
        }
    }

    // Also check for protected $guarded conflicts
    $guardedColumns = extractGuardedColumns($content);
    foreach ($guardedColumns as $column) {
        if (in_array($column, $relationshipMethods)) {
            $warnings[] = [
                'model' => $className,
                'file' => $file,
                'name' => $column,
                'type' => 'WARNING',
                'message' => "Guarded column '$column' may conflict with relationship method '$column()' depending on usage",
            ];
        }
    }
}

/**
 * Extract columns from $fillable array
 */
function extractFillableColumns(string $content): array
{
    $columns = [];

    // Match protected $fillable = [...];
    if (preg_match('/protected\s+\$fillable\s*=\s*\[([\s\S]*?)\];/m', $content, $matches)) {
        $fillableContent = $matches[1];
        // Extract quoted strings
        preg_match_all("/['\"]([^'\"]+)['\"]/", $fillableContent, $columnMatches);
        $columns = $columnMatches[1] ?? [];
    }

    return $columns;
}

/**
 * Extract columns from casts() method or $casts property
 */
function extractCastsColumns(string $content): array
{
    $columns = [];

    // Match protected function casts(): array { return [...]; }
    if (preg_match('/protected\s+function\s+casts\s*\(\s*\)\s*:\s*array\s*\{\s*return\s*\[([\s\S]*?)\];\s*\}/m', $content, $matches)) {
        $castsContent = $matches[1];
        // Extract keys from key => value pairs
        preg_match_all("/['\"]([^'\"]+)['\"]\s*=>/", $castsContent, $columnMatches);
        $columns = array_merge($columns, $columnMatches[1] ?? []);
    }

    // Match protected $casts = [...];
    if (preg_match('/protected\s+\$casts\s*=\s*\[([\s\S]*?)\];/m', $content, $matches)) {
        $castsContent = $matches[1];
        preg_match_all("/['\"]([^'\"]+)['\"]\s*=>/", $castsContent, $columnMatches);
        $columns = array_merge($columns, $columnMatches[1] ?? []);
    }

    return array_unique($columns);
}

/**
 * Extract columns from $guarded array
 */
function extractGuardedColumns(string $content): array
{
    $columns = [];

    // Match protected $guarded = [...];
    if (preg_match('/protected\s+\$guarded\s*=\s*\[([\s\S]*?)\];/m', $content, $matches)) {
        $guardedContent = $matches[1];
        preg_match_all("/['\"]([^'\"]+)['\"]/", $guardedContent, $columnMatches);
        $columns = $columnMatches[1] ?? [];
    }

    return $columns;
}

/**
 * Extract relationship method names
 */
function extractRelationshipMethods(string $content): array
{
    $methods = [];

    // Relationship types to look for
    $relationshipTypes = [
        'HasOne',
        'HasMany',
        'BelongsTo',
        'BelongsToMany',
        'HasOneThrough',
        'HasManyThrough',
        'MorphOne',
        'MorphMany',
        'MorphTo',
        'MorphToMany',
        'MorphedByMany',
    ];

    $typePattern = implode('|', $relationshipTypes);

    // Match: public function methodName(): RelationType
    preg_match_all("/public\s+function\s+(\w+)\s*\(\s*\)\s*:\s*(?:$typePattern)/", $content, $matches);
    $methods = array_merge($methods, $matches[1] ?? []);

    // Also match relationships without type hints that use return $this->hasMany(), etc.
    preg_match_all("/public\s+function\s+(\w+)\s*\(\s*\)\s*\{[^}]*return\s+\\\$this\s*->\s*(?:hasOne|hasMany|belongsTo|belongsToMany|morphOne|morphMany|morphTo|morphToMany|morphedByMany|hasOneThrough|hasManyThrough)\s*\(/", $content, $matches);
    $methods = array_merge($methods, $matches[1] ?? []);

    return array_unique($methods);
}

// Output results
echo "\n";
echo "=======================================================\n";
echo "  Eloquent Relationship-Column Conflict Detector\n";
echo "=======================================================\n\n";

echo 'Scanned '.count($modelFiles)." model files in $modelsDir\n\n";

if (empty($conflicts) && empty($warnings)) {
    echo "\033[32m✓ No conflicts detected!\033[0m\n\n";
    exit(0);
}

$hasErrors = false;

if (! empty($conflicts)) {
    $hasErrors = true;
    echo "\033[31m✗ CONFLICTS FOUND (".count($conflicts)."):\033[0m\n\n";

    foreach ($conflicts as $conflict) {
        echo "  \033[31m[{$conflict['type']}]\033[0m {$conflict['model']}\n";
        echo "    File: {$conflict['file']}\n";
        echo "    {$conflict['message']}\n";
        echo "    \033[33mFix: Rename the relationship method to avoid shadowing the column.\033[0m\n";
        echo "    Example: Rename '{$conflict['name']}()' to 'get".ucfirst($conflict['name'])."()' or use a different name.\n\n";
    }
}

if (! empty($warnings)) {
    echo "\033[33m⚠ WARNINGS (".count($warnings)."):\033[0m\n\n";

    foreach ($warnings as $warning) {
        echo "  \033[33m[{$warning['type']}]\033[0m {$warning['model']}\n";
        echo "    File: {$warning['file']}\n";
        echo "    {$warning['message']}\n\n";
    }
}

echo "=======================================================\n";
echo "Summary:\n";
echo '  - Models scanned: '.count($modelFiles)."\n";
echo '  - Conflicts: '.count($conflicts)."\n";
echo '  - Warnings: '.count($warnings)."\n";
echo "=======================================================\n\n";

if ($hasErrors) {
    echo "\033[31mPlease fix the conflicts above to prevent runtime bugs.\033[0m\n\n";
    exit(1);
}

exit(0);
