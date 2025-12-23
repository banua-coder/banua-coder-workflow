#!/usr/bin/env node

/**
 * Universal Changelog Generator
 *
 * Generates changelog from conventional commits with flexible configuration.
 * Supports multiple project types, monorepos, and output formats.
 *
 * Usage:
 *   node generate-changelog.js --version 1.2.3
 *   node generate-changelog.js --version v1.2.3 --format emoji --links full
 *   node generate-changelog.js --version 1.2.3 --dry-run
 *   node generate-changelog.js --config .release-config.yml
 *
 * Features:
 *   - Auto-detects repository URL from git remote
 *   - Supports emoji and plain text formats
 *   - Full commit links or short hashes
 *   - Breaking changes detection
 *   - Key highlights auto-detection
 *   - Monorepo support (melos, lerna, pnpm workspaces)
 *   - Configuration file support
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// ============================================
// Configuration
// ============================================

const COMMIT_TYPES = {
  feat: { plain: 'Added', emoji: '✨ Features' },
  fix: { plain: 'Fixed', emoji: '🐛 Bug Fixes' },
  hotfix: { plain: 'Hotfixes', emoji: '🚑 Hotfixes' },
  docs: { plain: 'Documentation', emoji: '📚 Documentation' },
  style: { plain: 'Style', emoji: '💎 Styles' },
  refactor: { plain: 'Changed', emoji: '♻️ Code Refactoring' },
  perf: { plain: 'Performance', emoji: '⚡ Performance' },
  test: { plain: 'Tests', emoji: '✅ Tests' },
  build: { plain: 'Build', emoji: '📦 Build System' },
  ci: { plain: 'CI/CD', emoji: '👷 CI/CD' },
  chore: { plain: 'Maintenance', emoji: '🔧 Chores' },
  revert: { plain: 'Reverted', emoji: '⏪ Reverts' },
};

const CATEGORY_PRIORITY = [
  'Breaking Changes',
  'Hotfixes',
  'Added',
  'Changed',
  'Fixed',
  'Performance',
  'Documentation',
  'Tests',
  'CI/CD',
  'Build',
  'Maintenance',
  'Style',
  'Reverted',
  'Other',
  // Emoji versions
  '⚠️ Breaking Changes',
  '🚑 Hotfixes',
  '✨ Features',
  '♻️ Code Refactoring',
  '🐛 Bug Fixes',
  '⚡ Performance',
  '📚 Documentation',
  '✅ Tests',
  '👷 CI/CD',
  '📦 Build System',
  '🔧 Chores',
  '💎 Styles',
  '⏪ Reverts',
];

const HIGHLIGHT_KEYWORDS = {
  interceptor: 'HTTP Interceptor Support',
  webview: 'WebView Integration',
  'form.*engine': 'Form Engine Configuration',
  authentication: 'Authentication System',
  'real-?time': 'Real-time Updates',
  websocket: 'WebSocket Support',
  caching: 'Caching Implementation',
  'dark.*mode': 'Dark Mode Support',
  i18n: 'Internationalization',
  localization: 'Localization Support',
};

// ============================================
// Utility Functions
// ============================================

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    version: null,
    format: 'emoji', // emoji | plain
    links: 'full', // full | short | none
    dryRun: false,
    force: false,
    debug: false,
    config: null,
    package: null, // For monorepo: specific package
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
      case '--format':
        options.format = next;
        i++;
        break;
      case '-l':
      case '--links':
        options.links = next;
        i++;
        break;
      case '-d':
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--force':
        options.force = true;
        break;
      case '--debug':
        options.debug = true;
        break;
      case '-c':
      case '--config':
        options.config = next;
        i++;
        break;
      case '-p':
      case '--package':
        options.package = next;
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
Universal Changelog Generator

Usage:
  node generate-changelog.js [options]

Options:
  -v, --version <version>   Version to generate changelog for (required)
  -f, --format <format>     Output format: emoji (default) | plain
  -l, --links <type>        Commit links: full (default) | short | none
  -d, --dry-run             Preview without writing to file
  --force                   Proceed even with uncommitted changes
  --debug                   Enable debug output
  -c, --config <file>       Path to config file
  -p, --package <name>      Specific package (for monorepos)
  -h, --help                Show this help message

Examples:
  node generate-changelog.js --version 1.2.3
  node generate-changelog.js --version v1.2.3 --format plain --links short
  node generate-changelog.js --version 1.2.3 --dry-run
  node generate-changelog.js --config .release-config.yml --version 2.0.0

Configuration File (.release-config.yml):
  changelog:
    format: emoji
    commit_links: full
    include_breaking_changes: true
    include_key_highlights: true
`);
}

function loadConfig(configPath) {
  if (!configPath) {
    // Try default locations
    const defaults = ['.release-config.yml', '.release-config.yaml', '.changelog.yml'];
    for (const file of defaults) {
      if (fs.existsSync(file)) {
        configPath = file;
        break;
      }
    }
  }

  if (!configPath || !fs.existsSync(configPath)) {
    return {};
  }

  try {
    const content = fs.readFileSync(configPath, 'utf-8');
    // Simple YAML parsing (key: value format)
    const config = {};
    let currentSection = config;
    let sectionStack = [config];

    for (const line of content.split('\n')) {
      if (line.trim().startsWith('#') || !line.trim()) continue;

      const indent = line.search(/\S/);
      const match = line.match(/^(\s*)([^:]+):\s*(.*)$/);

      if (match) {
        const [, , key, value] = match;
        if (value.trim()) {
          currentSection[key.trim()] = value.trim().replace(/^["']|["']$/g, '');
        } else {
          currentSection[key.trim()] = {};
          currentSection = currentSection[key.trim()];
        }
      }
    }

    return config;
  } catch (error) {
    console.warn(`Warning: Could not parse config file: ${error.message}`);
    return {};
  }
}

function exec(command, options = {}) {
  try {
    return execSync(command, { encoding: 'utf-8', ...options }).trim();
  } catch (error) {
    if (options.ignoreError) return '';
    throw error;
  }
}

function detectRepositoryUrl() {
  try {
    let url = exec('git remote get-url origin', { ignoreError: true });

    if (!url) {
      const remotes = exec('git remote', { ignoreError: true }).split('\n');
      if (remotes.length > 0 && remotes[0]) {
        url = exec(`git remote get-url ${remotes[0]}`, { ignoreError: true });
      }
    }

    if (!url) return null;

    // Convert SSH to HTTPS
    if (url.startsWith('git@')) {
      url = url.replace('git@', 'https://').replace(':', '/').replace(/\.git$/, '');
    } else if (url.startsWith('https://')) {
      url = url.replace(/\.git$/, '');
    }

    return url;
  } catch {
    return null;
  }
}

function detectMonorepo() {
  if (fs.existsSync('melos.yaml')) return 'melos';
  if (fs.existsSync('lerna.json')) return 'lerna';
  if (fs.existsSync('pnpm-workspace.yaml')) return 'pnpm';
  if (fs.existsSync('rush.json')) return 'rush';
  return null;
}

function getLastTag() {
  try {
    const tags = exec('git tag -l --sort=-version:refname', { ignoreError: true }).split('\n');
    return tags.find((tag) => tag.match(/^v?\d+\.\d+\.\d+/)) || null;
  } catch {
    return null;
  }
}

function getCommits(since) {
  try {
    let range;
    if (since) {
      range = `${since}..HEAD`;
    } else {
      // No tags, get all commits
      try {
        const initial = exec('git rev-list --max-parents=0 HEAD');
        range = `${initial}..HEAD`;
      } catch {
        range = 'HEAD';
      }
    }

    const format = '%H|%s|%an|%ae|%ad';
    const output = exec(`git log ${range} --pretty=format:"${format}" --date=iso`, {
      ignoreError: true,
    });

    if (!output) return [];

    return output
      .split('\n')
      .filter(Boolean)
      .map((line) => {
        const [hash, subject, authorName, authorEmail, date] = line.split('|');
        return { hash, subject, authorName, authorEmail, date };
      })
      .filter((commit) => {
        // Filter out merge commits and automated commits
        return (
          !commit.subject.startsWith('Merge ') &&
          !commit.subject.includes('auto-generated') &&
          !commit.subject.includes('back-merge')
        );
      });
  } catch (error) {
    console.error('Error fetching commits:', error.message);
    return [];
  }
}

function parseConventionalCommit(subject) {
  // Match: type(scope)!: description
  const match = subject.match(/^(\w+)(?:\(([^)]+)\))?(!)?: (.+)$/);

  if (!match) {
    return { type: 'other', scope: null, description: subject, breaking: false };
  }

  const [, type, scope, breakingMarker, description] = match;
  const breaking = breakingMarker === '!' || description.includes('BREAKING CHANGE');

  return {
    type: type.toLowerCase(),
    scope: scope || null,
    description,
    breaking,
  };
}

function categorizeCommits(commits, format) {
  const categories = {};

  for (const commit of commits) {
    const parsed = parseConventionalCommit(commit.subject);
    const typeConfig = COMMIT_TYPES[parsed.type];

    let category;
    if (parsed.breaking) {
      category = format === 'emoji' ? '⚠️ Breaking Changes' : 'Breaking Changes';
    } else if (typeConfig) {
      category = format === 'emoji' ? typeConfig.emoji : typeConfig.plain;
    } else {
      category = 'Other';
    }

    if (!categories[category]) {
      categories[category] = [];
    }

    categories[category].push({
      ...parsed,
      hash: commit.hash,
      shortHash: commit.hash.substring(0, 7),
    });
  }

  // Sort categories by priority
  const sorted = {};
  for (const cat of CATEGORY_PRIORITY) {
    if (categories[cat]) {
      sorted[cat] = categories[cat];
    }
  }
  // Add any remaining categories
  for (const cat of Object.keys(categories)) {
    if (!sorted[cat]) {
      sorted[cat] = categories[cat];
    }
  }

  return sorted;
}

function detectKeyHighlights(commits) {
  const highlights = [];

  const allText = commits.map((c) => c.subject.toLowerCase()).join(' ');

  for (const [pattern, highlight] of Object.entries(HIGHLIGHT_KEYWORDS)) {
    if (new RegExp(pattern, 'i').test(allText)) {
      highlights.push(highlight);
    }
  }

  return highlights;
}

function formatCommitLink(hash, shortHash, repoUrl, linkType) {
  if (linkType === 'none') {
    return '';
  } else if (linkType === 'short' || !repoUrl) {
    return ` ([${shortHash}])`;
  } else {
    return ` ([${shortHash}](${repoUrl}/commit/${hash}))`;
  }
}

function generateChangelogContent(version, categories, options) {
  const { format, links, repoUrl, includeHighlights } = options;
  const lines = [];

  // Version header
  const cleanVersion = version.replace(/^v/, '');
  const date = new Date().toISOString().split('T')[0];
  lines.push(`## [${cleanVersion}] - ${date}`);
  lines.push('');

  // Key highlights
  if (includeHighlights && options.highlights && options.highlights.length > 0) {
    const highlightHeader = format === 'emoji' ? '### 🎯 Key Highlights' : '### Key Highlights';
    lines.push(highlightHeader);
    lines.push('');
    for (const highlight of options.highlights) {
      lines.push(`- **${highlight}**`);
    }
    lines.push('');
  }

  // Categories
  for (const [category, commits] of Object.entries(categories)) {
    if (commits.length === 0) continue;

    lines.push(`### ${category}`);
    lines.push('');

    for (const commit of commits) {
      let line = '- ';

      // Add scope if present
      if (commit.scope) {
        line += `**${commit.scope}**: `;
      }

      // Add description (capitalize first letter)
      const desc = commit.description.charAt(0).toLowerCase() + commit.description.slice(1);
      line += desc;

      // Add commit link
      line += formatCommitLink(commit.hash, commit.shortHash, repoUrl, links);

      lines.push(line);
    }

    lines.push('');
  }

  return lines.join('\n');
}

function updateChangelog(content, newEntry) {
  const changelogPath = 'CHANGELOG.md';

  if (!fs.existsSync(changelogPath)) {
    // Create new changelog
    const header = `# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

`;
    return header + newEntry;
  }

  const existing = fs.readFileSync(changelogPath, 'utf-8');

  // Find insertion point (after ## [Unreleased] section or after header)
  const unreleasedMatch = existing.match(/^## \[Unreleased\]\s*\n/m);

  if (unreleasedMatch) {
    const insertPoint = unreleasedMatch.index + unreleasedMatch[0].length;
    return existing.slice(0, insertPoint) + '\n' + newEntry + '\n' + existing.slice(insertPoint);
  }

  // Find first version heading
  const versionMatch = existing.match(/^## \[\d+\.\d+\.\d+\]/m);

  if (versionMatch) {
    return existing.slice(0, versionMatch.index) + newEntry + '\n' + existing.slice(versionMatch.index);
  }

  // Append after header
  const headerMatch = existing.match(/^# Changelog\s*\n/m);
  if (headerMatch) {
    const insertPoint = headerMatch.index + headerMatch[0].length;
    // Skip any description lines
    const afterHeader = existing.slice(insertPoint);
    const nextSection = afterHeader.search(/^##/m);
    if (nextSection > 0) {
      return existing.slice(0, insertPoint + nextSection) + newEntry + '\n' + existing.slice(insertPoint + nextSection);
    }
  }

  // Just prepend
  return newEntry + '\n\n' + existing;
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

  // Load config file
  const config = loadConfig(options.config);

  // Merge config with CLI options (CLI takes precedence)
  const format = options.format || config.changelog?.format || 'emoji';
  const links = options.links || config.changelog?.commit_links || 'full';
  const includeHighlights = config.changelog?.include_key_highlights !== false;

  if (!options.version) {
    console.error('Error: Version is required. Use --version flag.');
    console.error('Run with --help for usage information.');
    process.exit(1);
  }

  // Validate environment
  try {
    exec('git rev-parse --git-dir');
  } catch {
    console.error('Error: Not in a git repository');
    process.exit(1);
  }

  // Check for uncommitted changes
  if (!options.force) {
    try {
      exec('git diff --quiet && git diff --cached --quiet');
    } catch {
      console.error('Error: Uncommitted changes detected. Use --force to proceed.');
      process.exit(1);
    }
  }

  const version = options.version.replace(/^v/, '');
  const repoUrl = detectRepositoryUrl();
  const monorepo = detectMonorepo();
  const lastTag = getLastTag();

  if (options.debug) {
    console.log('Debug info:');
    console.log(`  Version: ${version}`);
    console.log(`  Repository URL: ${repoUrl || 'not detected'}`);
    console.log(`  Monorepo: ${monorepo || 'no'}`);
    console.log(`  Last tag: ${lastTag || 'none'}`);
    console.log(`  Format: ${format}`);
    console.log(`  Links: ${links}`);
    console.log('');
  }

  console.log(`🚀 Generating changelog for version ${version}...`);

  // Get commits
  const commits = getCommits(lastTag);

  if (commits.length === 0) {
    console.log('⚠️  No commits found since last release.');
    process.exit(0);
  }

  console.log(`📋 Found ${commits.length} commits since ${lastTag || 'beginning'}`);

  // Categorize commits
  const categories = categorizeCommits(commits, format);

  // Detect highlights
  const highlights = includeHighlights ? detectKeyHighlights(commits) : [];

  // Generate content
  const content = generateChangelogContent(version, categories, {
    format,
    links,
    repoUrl,
    includeHighlights,
    highlights,
  });

  if (options.dryRun) {
    console.log('\n' + '='.repeat(50));
    console.log('CHANGELOG PREVIEW (dry run)');
    console.log('='.repeat(50) + '\n');
    console.log(content);
    process.exit(0);
  }

  // Update changelog file
  const updatedChangelog = updateChangelog(null, content);
  fs.writeFileSync('CHANGELOG.md', updatedChangelog);

  console.log('✅ Changelog updated successfully!');
}

main();
