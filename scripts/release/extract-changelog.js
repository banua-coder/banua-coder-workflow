#!/usr/bin/env node

/**
 * Changelog Section Extractor
 *
 * Extracts a specific version's changelog section from CHANGELOG.md
 * Useful for GitHub release notes and automated release workflows.
 *
 * Usage:
 *   node extract-changelog.js --version 1.2.3
 *   node extract-changelog.js --version v1.2.3 --file CHANGELOG.md
 *   node extract-changelog.js --version latest
 *
 * Output:
 *   Prints the extracted section to stdout
 */

const fs = require('fs');
const path = require('path');

// ============================================
// Configuration
// ============================================

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    version: null,
    file: 'CHANGELOG.md',
    help: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const next = args[i + 1];

    switch (arg) {
      case '-v':
      case '--version':
        options.version = next;
        i++;
        break;
      case '-f':
      case '--file':
        options.file = next;
        i++;
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
    }
  }

  return options;
}

function showHelp() {
  console.log(`
Changelog Section Extractor

Usage:
  node extract-changelog.js [options]

Options:
  -v, --version <version>   Version to extract (required, or 'latest')
  -f, --file <file>         Changelog file (default: CHANGELOG.md)
  -h, --help                Show this help message

Examples:
  node extract-changelog.js --version 1.2.3
  node extract-changelog.js --version v1.2.3 --file CHANGELOG.md
  node extract-changelog.js --version latest

Output:
  The extracted changelog section is printed to stdout.
  This can be piped to a file or used in GitHub Actions:

    # In GitHub Actions:
    NOTES=$(node extract-changelog.js --version \${{ github.ref_name }})
    gh release create \${{ github.ref_name }} --notes "$NOTES"
`);
}

// ============================================
// Main Functions
// ============================================

function extractSection(content, targetVersion) {
  // Clean version (remove 'v' prefix for matching)
  const cleanVersion = targetVersion.replace(/^v/, '');

  // Handle 'latest' - find first version
  if (targetVersion.toLowerCase() === 'latest') {
    const versionMatch = content.match(/^## \[(\d+\.\d+\.\d+[^\]]*)\]/m);
    if (versionMatch) {
      return extractSection(content, versionMatch[1]);
    }
    return null;
  }

  // Find the version header
  // Match formats: ## [1.2.3], ## [v1.2.3], ## 1.2.3
  const versionPatterns = [
    `## \\[${cleanVersion}\\]`, // [1.2.3]
    `## \\[v${cleanVersion}\\]`, // [v1.2.3]
    `## ${cleanVersion}[^\\d]`, // 1.2.3 (without brackets)
  ];

  let startIndex = -1;
  let headerLine = '';

  for (const pattern of versionPatterns) {
    const regex = new RegExp(`^(${pattern}.*)$`, 'm');
    const match = content.match(regex);
    if (match) {
      startIndex = match.index;
      headerLine = match[1];
      break;
    }
  }

  if (startIndex === -1) {
    return null;
  }

  // Find the end (next version header or end of file)
  const afterStart = content.slice(startIndex + headerLine.length);
  const nextVersionMatch = afterStart.match(/^## (\[?\d+\.\d+\.\d+|Unreleased)/m);

  let endIndex;
  if (nextVersionMatch) {
    endIndex = startIndex + headerLine.length + nextVersionMatch.index;
  } else {
    endIndex = content.length;
  }

  // Extract and clean the section
  let section = content.slice(startIndex, endIndex).trim();

  // Remove the version header if user wants just the content
  // (keeping it for now as it's useful context)

  return section;
}

function extractContentOnly(content, targetVersion) {
  const section = extractSection(content, targetVersion);
  if (!section) return null;

  // Remove the version header line
  const lines = section.split('\n');
  const contentLines = lines.slice(1); // Remove first line (header)

  // Trim leading/trailing empty lines
  while (contentLines.length > 0 && contentLines[0].trim() === '') {
    contentLines.shift();
  }
  while (contentLines.length > 0 && contentLines[contentLines.length - 1].trim() === '') {
    contentLines.pop();
  }

  return contentLines.join('\n');
}

// ============================================
// Main
// ============================================

function main() {
  const options = parseArgs();

  if (options.help) {
    showHelp();
    process.exit(0);
  }

  if (!options.version) {
    console.error('Error: Version is required. Use --version flag.');
    console.error('Run with --help for usage information.');
    process.exit(1);
  }

  // Check if changelog file exists
  if (!fs.existsSync(options.file)) {
    console.error(`Error: File not found: ${options.file}`);
    process.exit(1);
  }

  // Read changelog
  const content = fs.readFileSync(options.file, 'utf-8');

  // Extract section
  const section = extractContentOnly(content, options.version);

  if (!section) {
    console.error(`Error: Version ${options.version} not found in ${options.file}`);
    process.exit(1);
  }

  // Output to stdout
  console.log(section);
}

main();
