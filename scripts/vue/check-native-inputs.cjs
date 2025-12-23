#!/usr/bin/env node

/**
 * Script to check for native HTML input fields that should use shadcn-vue components
 *
 * Usage: node scripts/check-native-inputs.cjs [pages-path] [components-path]
 *
 * This script scans Vue files for native HTML input elements that should be replaced
 * with shadcn-vue components for consistency and better UX.
 */

const fs = require('fs');
const path = require('path');

// Get paths from arguments or use defaults
const pagesPath = process.argv[2] || path.join(process.cwd(), 'resources/js/pages');
const componentsPath = process.argv[3] || path.join(process.cwd(), 'resources/js/components');

// Patterns to detect and their recommended replacements
// Note: Patterns use lowercase to match native HTML elements only (not Vue components like <Input>)
const nativeInputPatterns = [
    {
        // Native date input: <input type="date" (lowercase only)
        pattern: /<input\s[^>]*\btype\s*=\s*["']date["'][^>]*>/g,
        name: 'Native date input',
        replacement: 'DatePicker from @/components/ui/date-picker',
    },
    {
        // Native time input: <input type="time" (lowercase only)
        pattern: /<input\s[^>]*\btype\s*=\s*["']time["'][^>]*>/g,
        name: 'Native time input',
        replacement: 'TimePicker from @/components/ui/time-picker',
    },
    {
        // Native datetime-local input (lowercase only)
        pattern: /<input\s[^>]*\btype\s*=\s*["']datetime-local["'][^>]*>/g,
        name: 'Native datetime-local input',
        replacement: 'DateTimePicker from @/components/ui/date-time-picker',
    },
    {
        // Native select element (lowercase only, not Select component)
        pattern: /<select\s[^>]*>[\s\S]*?<\/select>/g,
        name: 'Native select element',
        replacement: 'Select from @/components/ui/select',
    },
    {
        // Native checkbox input (lowercase only, not Checkbox component)
        pattern: /<input\s[^>]*\btype\s*=\s*["']checkbox["'][^>]*>/g,
        name: 'Native checkbox input',
        replacement: 'Checkbox from @/components/ui/checkbox',
    },
    {
        // Native radio input (lowercase only)
        pattern: /<input\s[^>]*\btype\s*=\s*["']radio["'][^>]*>/g,
        name: 'Native radio input',
        replacement: 'RadioGroup from @/components/ui/radio-group',
    },
    {
        // Native file input (lowercase only) - often necessary, so just warn
        pattern: /<input\s[^>]*\btype\s*=\s*["']file["'][^>]*>/g,
        name: 'Native file input',
        replacement: 'Consider using a custom file upload component (may be acceptable)',
        // File inputs are often necessary, don't fail the build
        warnOnly: true,
    },
    {
        // Native range/slider input (lowercase only)
        pattern: /<input\s[^>]*\btype\s*=\s*["']range["'][^>]*>/g,
        name: 'Native range input',
        replacement: 'Slider from @/components/ui/slider',
    },
    {
        // Native textarea (lowercase only, should use Textarea component)
        pattern: /<textarea\s[^>]*>[\s\S]*?<\/textarea>/g,
        name: 'Native textarea element',
        replacement: 'Textarea from @/components/ui/textarea',
    },
];

// Directories/files to exclude from scanning
const excludePaths = [
    'components/ui/', // shadcn-vue components themselves
    'node_modules/',
    '.nuxt/',
    'dist/',
];

function shouldExclude(filePath) {
    return excludePaths.some(exclude => filePath.includes(exclude));
}

function getAllVueFiles(dir) {
    const files = [];

    if (!fs.existsSync(dir)) {
        return files;
    }

    const items = fs.readdirSync(dir);

    for (const item of items) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);

        if (stat.isDirectory()) {
            files.push(...getAllVueFiles(fullPath));
        } else if (item.endsWith('.vue') && !shouldExclude(fullPath)) {
            files.push(fullPath);
        }
    }

    return files;
}

function getLineNumber(content, index) {
    return content.substring(0, index).split('\n').length;
}

function scanFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const issues = [];

    // Only scan the template section
    const templateMatch = content.match(/<template[^>]*>([\s\S]*?)<\/template>/i);
    if (!templateMatch) {
        return issues;
    }

    const templateContent = templateMatch[1];
    const templateStart = content.indexOf(templateMatch[0]);

    for (const rule of nativeInputPatterns) {
        let match;
        const pattern = new RegExp(rule.pattern.source, rule.pattern.flags);

        while ((match = pattern.exec(templateContent)) !== null) {
            // Check exclusion pattern if exists
            if (rule.excludePattern && rule.excludePattern.test(templateContent)) {
                continue;
            }

            // Run custom validation if exists
            if (rule.validate && !rule.validate(match[0], content)) {
                continue;
            }

            const lineNumber = getLineNumber(content, templateStart + match.index);

            issues.push({
                file: filePath,
                line: lineNumber,
                type: rule.name,
                replacement: rule.replacement,
                match: match[0].substring(0, 60) + (match[0].length > 60 ? '...' : ''),
                warnOnly: rule.warnOnly || false,
            });
        }
    }

    return issues;
}

// Main execution
console.log('Scanning for native HTML input elements that should use shadcn-vue components...\n');

const allFiles = [
    ...getAllVueFiles(pagesPath),
    ...getAllVueFiles(componentsPath),
];

let allIssues = [];

for (const file of allFiles) {
    const issues = scanFile(file);
    allIssues.push(...issues);
}

// Separate errors from warnings
const errors = allIssues.filter(issue => !issue.warnOnly);
const warnings = allIssues.filter(issue => issue.warnOnly);

if (allIssues.length === 0) {
    console.log('✅ No native HTML input elements found. All inputs use shadcn-vue components.\n');
    process.exit(0);
}

// Group by file
const groupedByFile = {};
for (const issue of allIssues) {
    const relativePath = issue.file.replace(process.cwd() + '/', '');
    if (!groupedByFile[relativePath]) {
        groupedByFile[relativePath] = [];
    }
    groupedByFile[relativePath].push(issue);
}

if (errors.length > 0) {
    console.log(`Found ${errors.length} native input element(s) that must use shadcn-vue components:\n`);
}

if (warnings.length > 0 && errors.length === 0) {
    console.log(`Found ${warnings.length} warning(s) (acceptable but worth reviewing):\n`);
} else if (warnings.length > 0) {
    console.log(`Also found ${warnings.length} warning(s) (acceptable but worth reviewing):\n`);
}

for (const [file, issues] of Object.entries(groupedByFile)) {
    console.log(`📁 ${file}`);
    for (const issue of issues) {
        const icon = issue.warnOnly ? '💡' : '❌';
        console.log(`   ${icon} Line ${issue.line}: ${issue.type}`);
        console.log(`      Found: ${issue.match}`);
        console.log(`      Use: ${issue.replacement}`);
    }
    console.log('');
}

if (errors.length > 0) {
    console.log('Suggestions:');
    console.log('  - Replace native HTML inputs with shadcn-vue components for consistency');
    console.log('  - Import components from @/components/ui/');
    console.log('  - See: https://www.shadcn-vue.com/docs/components');
    console.log('');
    process.exit(1);
} else {
    console.log('✅ All warnings are acceptable. No blocking issues found.\n');
    process.exit(0);
}
