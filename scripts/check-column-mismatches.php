<?php

/**
 * Database Column Mismatch Checker
 *
 * This script compares database migration columns with model fillables,
 * repository SQL queries, and form request validations to identify mismatches.
 *
 * Usage: php scripts/check-column-mismatches.php
 */
$basePath = dirname(__DIR__);

echo "\n";
echo "╔══════════════════════════════════════════════════════════════════════════════╗\n";
echo "║              DATABASE COLUMN MISMATCH CHECKER                                ║\n";
echo "╚══════════════════════════════════════════════════════════════════════════════╝\n\n";

$totalIssues = 0;
$criticalIssues = 0;
$highIssues = 0;
$mediumIssues = 0;

/**
 * Extract columns from a migration file
 */
function extractMigrationColumns(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match table column definitions
    $patterns = [
        '/\$table->(?:string|text|integer|bigInteger|unsignedInteger|unsignedBigInteger|unsignedTinyInteger|unsignedSmallInteger|tinyInteger|smallInteger|decimal|float|double|boolean|date|dateTime|timestamp|time|json|enum|foreignId)\s*\(\s*[\'"]([^"\']+)[\'"]/m',
    ];

    foreach ($patterns as $pattern) {
        if (preg_match_all($pattern, $content, $matches)) {
            $columns = array_merge($columns, $matches[1]);
        }
    }

    // Remove common auto columns that shouldn't be in fillable
    $autoColumns = ['id', 'created_at', 'updated_at', 'deleted_at'];
    $columns = array_diff($columns, $autoColumns);

    return array_unique($columns);
}

/**
 * Extract fillable columns from a model file
 */
function extractModelFillable(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match fillable array
    if (preg_match('/protected\s+\$fillable\s*=\s*\[(.*?)\];/s', $content, $match)) {
        if (preg_match_all('/[\'"]([^\'"]+)[\'"]/', $match[1], $colMatches)) {
            $columns = $colMatches[1];
        }
    }

    return $columns;
}

/**
 * Extract casts from a model file
 */
function extractModelCasts(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match casts array (both property and method syntax)
    if (preg_match('/(?:protected\s+\$casts\s*=\s*\[|protected\s+function\s+casts\s*\(\s*\)\s*:\s*array\s*\{\s*return\s*\[)(.*?)\];/s', $content, $match)) {
        if (preg_match_all('/[\'"]([^\'"]+)[\'"]\s*=>/m', $match[1], $colMatches)) {
            $columns = $colMatches[1];
        }
    }

    return $columns;
}

/**
 * Extract validation rules from a request file
 */
function extractRequestRules(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match rules array
    if (preg_match('/public\s+function\s+rules\s*\(\s*\)\s*:\s*array\s*\{.*?return\s*\[(.*?)\];/s', $content, $match)) {
        if (preg_match_all('/[\'"]([^\'"\.]+)[\'"](?:\.[^\'"]+)?\s*=>/m', $match[1], $colMatches)) {
            $columns = $colMatches[1];
        }
    }

    return array_unique($columns);
}

/**
 * Extract SQL columns from a repository file
 */
function extractRepositoryColumns(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match SELECT columns (simplified)
    if (preg_match_all('/(?:ir|hr|gr|mr|br)\\.([a-z_]+)/m', $content, $matches)) {
        $columns = array_merge($columns, $matches[1]);
    }

    // Match array keys in insert/update
    if (preg_match_all('/[\'"]([a-z_]+)[\'"]\s*=>\s*\$(?:data|record)/m', $content, $matches)) {
        $columns = array_merge($columns, $matches[1]);
    }

    return array_unique($columns);
}

/**
 * Find matching files
 */
function findFiles(string $basePath, string $pattern): array
{
    $files = [];
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($basePath, RecursiveDirectoryIterator::SKIP_DOTS)
    );

    foreach ($iterator as $file) {
        if ($file->isFile() && fnmatch($pattern, $file->getFilename())) {
            $files[] = $file->getPathname();
        }
    }

    return $files;
}

/**
 * Get table name from migration filename
 */
function getTableNameFromMigration(string $filename): ?string
{
    if (preg_match('/create_([a-z_]+)_table\.php$/', $filename, $match)) {
        return $match[1];
    }

    return null;
}

/**
 * Get table name from "add to" migration filename
 */
function getTableNameFromAddMigration(string $filename): ?string
{
    // Match patterns like: add_*_to_{table}_table.php or add_*_{table}_table.php
    if (preg_match('/(?:add_[a-z_]+_to_|update_)([a-z_]+)(?:_table)?\.php$/', $filename, $match)) {
        return $match[1];
    }

    return null;
}

/**
 * Extract columns added by an "add to" migration
 */
function extractAddMigrationColumns(string $filePath): array
{
    $content = file_get_contents($filePath);
    $columns = [];

    // Match Schema::table modifications
    if (preg_match('/Schema::table\s*\([^)]+\s*,\s*function\s*\([^)]+\)\s*\{(.*?)\}\s*\)/s', $content, $tableMatch)) {
        $tableContent = $tableMatch[1];

        // Match column definitions
        $patterns = [
            '/\$table->(?:string|text|integer|bigInteger|unsignedInteger|unsignedBigInteger|unsignedTinyInteger|unsignedSmallInteger|tinyInteger|smallInteger|decimal|float|double|boolean|date|dateTime|timestamp|time|json|enum|foreignId)\s*\(\s*[\'"]([^"\']+)[\'"]/m',
        ];

        foreach ($patterns as $pattern) {
            if (preg_match_all($pattern, $tableContent, $matches)) {
                $columns = array_merge($columns, $matches[1]);
            }
        }

        // Check for column renames: renameColumn('old', 'new')
        if (preg_match_all('/renameColumn\s*\(\s*[\'"]([^\'"]+)[\'"]\s*,\s*[\'"]([^\'"]+)[\'"]\s*\)/', $tableContent, $renameMatches, PREG_SET_ORDER)) {
            foreach ($renameMatches as $rename) {
                $columns[] = '__RENAME__:'.$rename[1].'->'.$rename[2];
            }
        }
    }

    return array_unique($columns);
}

/**
 * Get model name from table name
 */
function tableToModelName(string $tableName): string
{
    // Convert snake_case plural to PascalCase singular
    $singular = rtrim($tableName, 's');
    if (str_ends_with($tableName, 'ies')) {
        $singular = substr($tableName, 0, -3).'y';
    } elseif (str_ends_with($tableName, 'es') && ! str_ends_with($tableName, 'ses')) {
        $singular = substr($tableName, 0, -2);
    }

    return str_replace(' ', '', ucwords(str_replace('_', ' ', $singular)));
}

/**
 * Extract the up() method content from a migration file
 */
function extractUpMethodContent(string $content): string
{
    // Find the up() method
    if (preg_match('/public\s+function\s+up\s*\(\s*\)\s*(?::\s*\w+\s*)?\{/', $content, $match, PREG_OFFSET_CAPTURE)) {
        $startPos = $match[0][1] + strlen($match[0][0]);
        $braceCount = 1;
        $endPos = $startPos;

        for ($i = $startPos; $i < strlen($content) && $braceCount > 0; $i++) {
            if ($content[$i] === '{') {
                $braceCount++;
            } elseif ($content[$i] === '}') {
                $braceCount--;
            }
            $endPos = $i;
        }

        return substr($content, $startPos, $endPos - $startPos);
    }

    return $content; // Fallback to full content if up() not found
}

/**
 * Extract columns from any migration that modifies a specific table
 */
function extractColumnsFromMigrationForTable(string $filePath, string $tableName): array
{
    $content = file_get_contents($filePath);
    // Only look in up() method to avoid down() canceling renames
    $upContent = extractUpMethodContent($content);

    $columns = [];
    $renamedColumns = [];

    // Match Schema::table('tableName', function) for modifications - match multiple blocks
    $tablePattern = '/Schema::table\s*\(\s*[\'"]'.preg_quote($tableName).'[\'"]\s*,\s*function\s*\([^)]*\)\s*(?::\s*\w+\s*)?\{/';

    // Find all Schema::table blocks for this table
    if (preg_match_all($tablePattern, $upContent, $matches, PREG_OFFSET_CAPTURE)) {
        foreach ($matches[0] as $match) {
            $startPos = $match[1] + strlen($match[0]);
            $braceCount = 1;
            $endPos = $startPos;

            // Find matching closing brace
            for ($i = $startPos; $i < strlen($upContent) && $braceCount > 0; $i++) {
                if ($upContent[$i] === '{') {
                    $braceCount++;
                } elseif ($upContent[$i] === '}') {
                    $braceCount--;
                }
                $endPos = $i;
            }

            $tableContent = substr($upContent, $startPos, $endPos - $startPos);

            // Match column definitions
            $colPattern = '/\$table->(?:string|text|integer|bigInteger|unsignedInteger|unsignedBigInteger|unsignedTinyInteger|unsignedSmallInteger|tinyInteger|smallInteger|decimal|float|double|boolean|date|dateTime|timestamp|time|json|enum|foreignId)\s*\(\s*[\'"]([^"\']+)[\'"]/m';

            if (preg_match_all($colPattern, $tableContent, $colMatches)) {
                $columns = array_merge($columns, $colMatches[1]);
            }

            // Check for column renames: $table->renameColumn('old', 'new')
            if (preg_match_all('/\$table->renameColumn\s*\(\s*[\'"]([^\'"]+)[\'"]\s*,\s*[\'"]([^\'"]+)[\'"]\s*\)/', $tableContent, $renameMatches, PREG_SET_ORDER)) {
                foreach ($renameMatches as $rename) {
                    $renamedColumns[$rename[1]] = $rename[2];
                }
            }
        }
    }

    return ['columns' => $columns, 'renames' => $renamedColumns];
}

/**
 * Get all columns for a table by scanning all migrations
 */
function getAllColumnsForTable(string $basePath, string $tableName): array
{
    $columns = [];
    $renamedColumns = [];

    // Get create migration
    $createMigrations = findFiles($basePath.'/database/migrations', "*_create_{$tableName}_table.php");
    foreach ($createMigrations as $migration) {
        $columns = array_merge($columns, extractMigrationColumns($migration));
    }

    // Scan ALL migrations for any that modify this table
    $allMigrations = glob($basePath.'/database/migrations/*.php');
    sort($allMigrations); // Sort by timestamp to apply in order

    foreach ($allMigrations as $migration) {
        // Skip create migrations (already processed)
        if (str_contains(basename($migration), "_create_{$tableName}_table")) {
            continue;
        }

        // Check if this migration modifies our table
        $content = file_get_contents($migration);
        if (str_contains($content, "'{$tableName}'") || str_contains($content, "\"{$tableName}\"")) {
            $result = extractColumnsFromMigrationForTable($migration, $tableName);
            $columns = array_merge($columns, $result['columns']);
            $renamedColumns = array_merge($renamedColumns, $result['renames']);
        }
    }

    // Apply renames
    foreach ($renamedColumns as $oldName => $newName) {
        $columns = array_diff($columns, [$oldName]);
        $columns[] = $newName;
    }

    // Remove common auto columns
    $autoColumns = ['id', 'created_at', 'updated_at', 'deleted_at'];
    $columns = array_diff($columns, $autoColumns);

    return array_unique(array_values($columns));
}

// Get all migrations
$migrations = findFiles($basePath.'/database/migrations', '*_create_*_table.php');

foreach ($migrations as $migrationPath) {
    $tableName = getTableNameFromMigration(basename($migrationPath));
    if (! $tableName) {
        continue;
    }

    $modelName = tableToModelName($tableName);
    $modelPath = $basePath.'/app/Models/'.$modelName.'.php';

    if (! file_exists($modelPath)) {
        continue;
    }

    // Get ALL columns including from add/update migrations
    $migrationColumns = getAllColumnsForTable($basePath, $tableName);
    $modelFillable = extractModelFillable($modelPath);
    $modelCasts = extractModelCasts($modelPath);

    // Skip if no fillable defined (might use guarded)
    if (empty($modelFillable)) {
        continue;
    }

    // Find mismatches
    $inMigrationNotModel = array_diff($migrationColumns, $modelFillable);
    $inModelNotMigration = array_diff($modelFillable, $migrationColumns);
    $inCastsNotMigration = array_diff($modelCasts, $migrationColumns, ['created_at', 'updated_at', 'deleted_at']);

    // Columns that are typically NOT in fillable (system/security columns)
    $systemColumns = [
        'email_verified_at', 'remember_token', 'token',
        'two_factor_secret', 'two_factor_recovery_codes', 'two_factor_confirmed_at',
        'password', 'ip_address', 'user_agent', 'last_activity', 'payload',
    ];
    $inMigrationNotModel = array_diff($inMigrationNotModel, $systemColumns);

    // Remove foreign key IDs from "not in model" check (they might be intentionally excluded)
    $inMigrationNotModel = array_filter($inMigrationNotModel, fn ($col) => ! str_ends_with($col, '_id') || in_array($col, $modelFillable));

    $hasIssues = ! empty($inMigrationNotModel) || ! empty($inModelNotMigration) || ! empty($inCastsNotMigration);

    if ($hasIssues) {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        echo "📋 Table: {$tableName}\n";
        echo "   Model: {$modelName}\n";
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    }

    if (! empty($inMigrationNotModel)) {
        $severity = count($inMigrationNotModel) > 3 ? 'CRITICAL' : 'HIGH';
        $icon = $severity === 'CRITICAL' ? '🔴' : '🟠';
        echo "\n{$icon} [{$severity}] Columns in migration but NOT in model fillable:\n";
        foreach ($inMigrationNotModel as $col) {
            echo "   - {$col}\n";
            $totalIssues++;
            if ($severity === 'CRITICAL') {
                $criticalIssues++;
            } else {
                $highIssues++;
            }
        }
    }

    if (! empty($inModelNotMigration)) {
        echo "\n🔴 [CRITICAL] Columns in model fillable but NOT in migration (will cause SQL errors):\n";
        foreach ($inModelNotMigration as $col) {
            echo "   - {$col}\n";
            $totalIssues++;
            $criticalIssues++;
        }
    }

    if (! empty($inCastsNotMigration)) {
        echo "\n🟡 [MEDIUM] Columns in casts but NOT in migration:\n";
        foreach ($inCastsNotMigration as $col) {
            echo "   - {$col}\n";
            $totalIssues++;
            $mediumIssues++;
        }
    }

    if ($hasIssues) {
        echo "\n";
    }
}

// Check repositories for column name mismatches
echo "\n";
echo "╔══════════════════════════════════════════════════════════════════════════════╗\n";
echo "║              REPOSITORY SQL COLUMN CHECK                                     ║\n";
echo "╚══════════════════════════════════════════════════════════════════════════════╝\n\n";

$repositories = findFiles($basePath.'/app/Repositories', '*.php');

foreach ($repositories as $repoPath) {
    $content = file_get_contents($repoPath);
    $repoName = basename($repoPath, '.php');

    // Check for common column naming issues
    $issues = [];

    // Only check immunization-related repositories for location -> facility_name
    $isImmunizationRepo = stripos($repoName, 'immunization') !== false;

    // Check for old column names that might be wrong
    $suspiciousPatterns = [
        'administrator' => 'Should this be "administered_by"?',
        'hemoglobin_g_dl' => 'Should this be "hemoglobin"?',
        'blood_sugar_mg_dl' => 'Should this be "blood_sugar_fasting" or "blood_sugar_postprandial"?',
        'last_menstrual_date' => 'Should this be "start_date"?',
    ];

    // Only add location check for immunization repositories
    if ($isImmunizationRepo) {
        $suspiciousPatterns['location'] = 'Should this be "facility_name"?';
    }

    foreach ($suspiciousPatterns as $pattern => $suggestion) {
        if (preg_match('/[\'"]'.preg_quote($pattern).'[\'"]/', $content) ||
            preg_match('/\.'.preg_quote($pattern).'(?:\s|,|\))/', $content) ||
            preg_match('/->'.preg_quote($pattern).'(?:\s|;|\))/', $content)) {
            $issues[] = "Found '{$pattern}': {$suggestion}";
        }
    }

    if (! empty($issues)) {
        echo "📁 {$repoName}\n";
        foreach ($issues as $issue) {
            echo "   ⚠️  {$issue}\n";
            $totalIssues++;
            $mediumIssues++;
        }
        echo "\n";
    }
}

// Check form requests
echo "\n";
echo "╔══════════════════════════════════════════════════════════════════════════════╗\n";
echo "║              FORM REQUEST VALIDATION CHECK                                   ║\n";
echo "╚══════════════════════════════════════════════════════════════════════════════╝\n\n";

$requests = findFiles($basePath.'/app/Http/Requests', '*.php');

foreach ($requests as $requestPath) {
    $content = file_get_contents($requestPath);
    $requestName = basename($requestPath, '.php');

    $issues = [];

    // Only check immunization-related requests for location -> facility_name
    $isImmunizationRequest = stripos($requestName, 'immunization') !== false;

    // Check for suspicious patterns in validation rules
    $suspiciousPatterns = [
        'hemoglobin_g_dl' => 'Should this be "hemoglobin"?',
        'blood_sugar_mg_dl' => 'Should this be "blood_sugar_fasting"?',
        'administrator' => 'Should this be "administered_by"?',
    ];

    // Only add location check for immunization requests
    if ($isImmunizationRequest) {
        $suspiciousPatterns['location'] = 'Should this be "facility_name"?';
    }

    foreach ($suspiciousPatterns as $pattern => $suggestion) {
        if (preg_match('/[\'"]'.preg_quote($pattern).'[\'"]/', $content)) {
            $issues[] = "Found '{$pattern}': {$suggestion}";
        }
    }

    if (! empty($issues)) {
        echo "📋 {$requestName}\n";
        foreach ($issues as $issue) {
            echo "   ⚠️  {$issue}\n";
            $totalIssues++;
            $mediumIssues++;
        }
        echo "\n";
    }
}

// Summary
echo "\n";
echo "╔══════════════════════════════════════════════════════════════════════════════╗\n";
echo "║                              SUMMARY                                         ║\n";
echo "╚══════════════════════════════════════════════════════════════════════════════╝\n\n";

if ($totalIssues === 0) {
    echo "✅ No column mismatches found!\n";
    echo "\n";
    exit(0);
} else {
    echo "Total issues found: {$totalIssues}\n";
    echo "  🔴 Critical: {$criticalIssues}\n";
    echo "  🟠 High:     {$highIssues}\n";
    echo "  🟡 Medium:   {$mediumIssues}\n";
    echo "\n";
    echo "⚠️  Please review and fix the issues above to prevent runtime errors.\n";
    echo "\n";
    // Exit with error code if there are critical issues
    exit($criticalIssues > 0 ? 1 : 0);
}
