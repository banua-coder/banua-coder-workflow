#!/usr/bin/env php
<?php

/**
 * Script to check for controllers using inline validation instead of FormRequest classes
 *
 * Usage: php scripts/check-missing-requests.php
 */
$controllersPath = __DIR__.'/../../app/Http/Controllers';

// Allow overriding the path via argument
if (isset($argv[1]) && is_dir($argv[1])) {
    $controllersPath = $argv[1];
}

if (! is_dir($controllersPath)) {
    // Try relative to cwd
    $controllersPath = getcwd().'/app/Http/Controllers';
}

if (! is_dir($controllersPath)) {
    echo "Error: Controllers directory not found\n";
    exit(1);
}

$files = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($controllersPath)
);

$issues = [];

foreach ($files as $file) {
    if ($file->isDir() || $file->getExtension() !== 'php') {
        continue;
    }

    $filePath = $file->getPathname();
    $content = file_get_contents($filePath);
    $relativePath = str_replace(getcwd().'/', '', $filePath);

    // Find inline $request->validate() calls
    if (preg_match_all('/\$request->validate\s*\(\s*\[/', $content, $matches, PREG_OFFSET_CAPTURE)) {
        foreach ($matches[0] as $match) {
            $lineNumber = substr_count(substr($content, 0, $match[1]), "\n") + 1;

            // Try to find the method name
            $beforeMatch = substr($content, 0, $match[1]);
            if (preg_match('/public\s+function\s+(\w+)\s*\([^)]*\)[^{]*\{[^}]*$/s', $beforeMatch, $methodMatch)) {
                $methodName = $methodMatch[1];
            } else {
                $methodName = 'unknown';
            }

            $issues[] = [
                'file' => $relativePath,
                'line' => $lineNumber,
                'method' => $methodName,
                'type' => 'inline_validate',
            ];
        }
    }

    // Find Request type hints without FormRequest (potential issues)
    if (preg_match_all('/public\s+function\s+(\w+)\s*\(\s*Request\s+\$request/', $content, $matches, PREG_OFFSET_CAPTURE)) {
        foreach ($matches[1] as $index => $match) {
            $methodName = $match[0];
            $lineNumber = substr_count(substr($content, 0, $match[1]), "\n") + 1;

            // Skip methods that typically don't need validation (read-only or standard CRUD)
            $skipMethods = [
                'index', 'show', 'create', 'edit', 'destroy',
                // Read-only API methods that only use query parameters
                'getSummary', 'getWeeklyStats', 'history', 'recommendations',
                'stats', 'guidelines', 'compare', 'concern', 'stop',
                // PIN verification methods (validated via session/middleware)
                'showVerify', 'check',
                // Webhook handlers (use raw request for signature verification)
                'handleInvoice',
            ];
            if (in_array($methodName, $skipMethods)) {
                continue;
            }

            // Check if this method has inline validation
            $methodStart = strpos($content, $matches[0][$index][0]);
            $methodEnd = strpos($content, 'public function', $methodStart + 1) ?: strlen($content);
            $methodContent = substr($content, $methodStart, $methodEnd - $methodStart);

            if (strpos($methodContent, '$request->validate') !== false) {
                // Already reported as inline_validate
                continue;
            }

            // Check if method uses request input without validation
            if (preg_match('/\$request->(input|get|post|query|all)\s*\(/', $methodContent)) {
                $issues[] = [
                    'file' => $relativePath,
                    'line' => $lineNumber,
                    'method' => $methodName,
                    'type' => 'no_validation',
                ];
            }
        }
    }
}

if (empty($issues)) {
    echo "✅ No issues found. All controllers use FormRequest classes properly.\n";
    exit(0);
}

echo '⚠️ Found '.count($issues)." potential issues:\n\n";

$groupedByFile = [];
foreach ($issues as $issue) {
    $groupedByFile[$issue['file']][] = $issue;
}

foreach ($groupedByFile as $file => $fileIssues) {
    echo "📁 {$file}\n";
    foreach ($fileIssues as $issue) {
        $icon = $issue['type'] === 'inline_validate' ? '⚠️ ' : '❓';
        $message = $issue['type'] === 'inline_validate'
            ? 'Inline $request->validate() - consider using FormRequest'
            : 'Uses request input without visible validation';
        echo "   {$icon} Line {$issue['line']}: {$issue['method']}() - {$message}\n";
    }
    echo "\n";
}

echo "Suggestions:\n";
echo "  - Create FormRequest classes: php artisan make:request Store{Model}Request\n";
echo "  - Move validation rules to the FormRequest's rules() method\n";
echo "  - Replace Request type hint with your FormRequest class\n";
