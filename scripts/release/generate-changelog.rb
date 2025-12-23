#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'optparse'

##
# Automatic Changelog Generator
#
# This script automatically generates changelog entries based on git commits
# following the Keep a Changelog format and Semantic Versioning principles.
#
# Features:
# - Categorizes commits by conventional commit types
# - Updates CHANGELOG.md with proper formatting
# - Includes commit links to GitHub
# - Robust error handling and validation
# - Force mode for bypassing uncommitted changes check
#
# Usage:
#   ruby generate-changelog.rb --version 1.2.3
#   ruby generate-changelog.rb --version v1.2.3 --force
class ChangelogGenerator
  # Conventional commit types and their changelog categories
  COMMIT_CATEGORIES = {
    'feat' => { category: 'Added', breaking: false },
    'fix' => { category: 'Fixed', breaking: false },
    'hotfix' => { category: 'Hotfixes', breaking: false },
    'docs' => { category: 'Documentation', breaking: false },
    'style' => { category: 'Style', breaking: false },
    'refactor' => { category: 'Changed', breaking: false },
    'perf' => { category: 'Performance', breaking: false },
    'test' => { category: 'Tests', breaking: false },
    'chore' => { category: 'Maintenance', breaking: false },
    'ci' => { category: 'CI/CD', breaking: false },
    'build' => { category: 'Build', breaking: false },
    'revert' => { category: 'Reverted', breaking: false },
    'merge' => { category: 'Merged Features', breaking: false }
  }.freeze

  # Release and hotfix branch patterns
  RELEASE_BRANCH_PATTERN = /^release\/v?(\d+)\.(\d+)\.(\d+)$/
  HOTFIX_BRANCH_PATTERN = /^hotfix\/v?(\d+)\.(\d+)\.(\d+)$/

  # Changelog file path
  CHANGELOG_PATH = 'CHANGELOG.md'

  attr_reader :options, :current_branch, :version_info, :repository_url

  ##
  # Initialize the changelog generator
  #
  # @param options [Hash] Configuration options
  def initialize(options = {})
    @options = default_options.merge(options)
    @current_branch = get_current_branch
    @version_info = parse_version_from_options_or_branch
    @repository_url = detect_repository_url
    validate_environment!
  end

  ##
  # Generate the changelog entry
  #
  # @return [Boolean] true if successful, false otherwise
  def generate!
    puts "Generating changelog for version #{version_string}..."

    commits = fetch_commits_since_last_release
    if commits.empty?
      puts "No commits found since last release. Nothing to generate."
      return false
    end

    categorized_commits = categorize_commits(commits)
    version_bump = determine_version_bump(commits)

    if options[:dry_run]
      preview_changelog(categorized_commits, version_bump)
    else
      update_changelog(categorized_commits, version_bump)
      puts "Changelog updated successfully!"
    end

    true
  rescue StandardError => e
    puts "Error generating changelog: #{e.message}"
    puts e.backtrace if options[:debug]
    false
  end

  private

  ##
  # Default configuration options
  #
  # @return [Hash] Default options
  def default_options
    {
      dry_run: false,
      debug: false,
      force: false,
      output_format: :markdown,
      version: nil,
      include_commit_links: true
    }
  end

  ##
  # Get the current git branch name
  #
  # @return [String] Current branch name
  # @raise [RuntimeError] if not in a git repository
  def get_current_branch
    branch = `git branch --show-current`.strip
    raise "Not in a git repository" if branch.empty?
    branch
  end

  ##
  # Detect repository URL from git remote
  #
  # @return [String, nil] Repository URL or nil if not found
  def detect_repository_url
    # Try to get origin URL
    url = `git remote get-url origin 2>/dev/null`.strip

    # If origin doesn't exist, try first available remote
    if url.empty?
      remotes = `git remote 2>/dev/null`.strip.split("\n")
      url = `git remote get-url #{remotes.first} 2>/dev/null`.strip unless remotes.empty?
    end

    return nil if url.empty?

    # Convert SSH URL to HTTPS URL
    if url.start_with?('git@')
      # git@github.com:user/repo.git -> https://github.com/user/repo
      url = url.sub('git@', 'https://')
               .sub(':', '/')
               .sub(/\.git$/, '')
    elsif url.start_with?('https://')
      # Remove .git suffix if present
      url = url.sub(/\.git$/, '')
    end

    puts "Repository URL: #{url}" if options[:debug]
    url
  rescue
    nil
  end

  ##
  # Parse version information from options or branch name
  #
  # @return [Hash] Version components (major, minor, patch)
  def parse_version_from_options_or_branch
    # If version is provided via command line, use that
    if options[:version]
      version = options[:version].to_s
      # Remove 'v' prefix if present
      version = version.sub(/^v/, '')

      if version.match(/^(\d+)\.(\d+)\.(\d+)$/)
        match = version.match(/^(\d+)\.(\d+)\.(\d+)$/)
        return {
          major: match[1].to_i,
          minor: match[2].to_i,
          patch: match[3].to_i
        }
      else
        raise "Invalid version format: #{options[:version]}. Expected format: x.y.z or vx.y.z"
      end
    end

    # Fallback to parsing from branch name
    release_match = current_branch.match(RELEASE_BRANCH_PATTERN)
    hotfix_match = current_branch.match(HOTFIX_BRANCH_PATTERN)
    match = release_match || hotfix_match

    if match
      {
        major: match[1].to_i,
        minor: match[2].to_i,
        patch: match[3].to_i
      }
    else
      # Allow any branch if version is explicitly provided
      if options[:version]
        raise "Invalid version format: #{options[:version]}"
      else
        raise "Not on a release or hotfix branch and no version specified. Expected format: release/vX.Y.Z or hotfix/vX.Y.Z, or use --version flag"
      end
    end
  end

  ##
  # Get the current version string
  #
  # @return [String] Version string (e.g., "v1.2.3")
  def version_string
    "v#{version_info[:major]}.#{version_info[:minor]}.#{version_info[:patch]}"
  end

  ##
  # Check if we're currently on a hotfix branch
  #
  # @return [Boolean] true if on hotfix branch, false if on release branch
  def hotfix_branch?
    current_branch.match?(HOTFIX_BRANCH_PATTERN)
  end

  ##
  # Validate the environment before proceeding
  #
  # @raise [RuntimeError] if environment is invalid
  def validate_environment!
    # Check if git is available
    system('git --version > /dev/null 2>&1') || raise("Git is not installed or not in PATH")

    # Check if we're in a git repository
    system('git rev-parse --git-dir > /dev/null 2>&1') || raise("Not in a git repository")

    # Create CHANGELOG.md if it doesn't exist
    unless File.exist?(CHANGELOG_PATH)
      puts "Creating #{CHANGELOG_PATH}..."
      File.write(CHANGELOG_PATH, <<~CHANGELOG)
        # Changelog

        All notable changes to this project will be documented in this file.

        The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
        and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

        ## [Unreleased]

      CHANGELOG
    end

    # Warn if there are uncommitted changes
    if has_uncommitted_changes? && !options[:force]
      raise "There are uncommitted changes. Use --force to proceed anyway."
    end

    puts "Environment validation passed" if options[:debug]
  end

  ##
  # Check if there are uncommitted changes
  #
  # @return [Boolean] true if there are uncommitted changes
  def has_uncommitted_changes?
    !system('git diff --quiet && git diff --cached --quiet')
  end

  ##
  # Fetch commits since the last release tag
  #
  # @return [Array<Hash>] Array of commit information
  def fetch_commits_since_last_release
    last_tag = get_last_release_tag
    range = last_tag ? "#{last_tag}..HEAD" : "HEAD"

    puts "Fetching commits since #{last_tag || 'beginning'}..." if options[:debug]

    commit_format = '%H|%s|%an|%ae|%ad'
    commits_output = `git log #{range} --pretty=format:"#{commit_format}" --date=iso`

    commits = commits_output.split("\n").map do |line|
      parts = line.split('|', 5)
      next if parts.length < 5

      {
        hash: parts[0],
        subject: parts[1],
        body: '',
        author_name: parts[2],
        author_email: parts[3],
        date: parts[4]
      }
    end.compact

    # Filter out merge commits and automated commits
    commits.reject! do |commit|
      commit[:subject].start_with?('Merge ') ||
      commit[:subject].include?('auto-generated') ||
      commit[:subject].include?('back-merge')
    end

    commits
  end

  ##
  # Get the last release tag
  #
  # @return [String, nil] Last release tag or nil if none exists
  def get_last_release_tag
    tags = `git tag -l --sort=-version:refname`.split("\n")
    tags.find { |tag| tag.match?(/^v\d+\.\d+\.\d+$/) }
  end

  ##
  # Categorize commits by their conventional commit type
  #
  # @param commits [Array<Hash>] Array of commit information
  # @return [Hash] Commits grouped by category
  def categorize_commits(commits)
    categories = Hash.new { |h, k| h[k] = [] }

    commits.each do |commit|
      type, scope, description, breaking = parse_conventional_commit(commit[:subject])

      # Determine category
      category_info = COMMIT_CATEGORIES[type] || { category: 'Other', breaking: false }
      category = breaking ? 'Breaking Changes' : category_info[:category]

      # Skip certain types if configured
      next if should_skip_commit?(type, commit)

      categories[category] << {
        type: type,
        scope: scope,
        description: description,
        breaking: breaking,
        commit: commit
      }
    end

    # Remove empty categories and sort
    categories.reject { |_, commits| commits.empty? }
             .sort_by { |category, _| category_priority(category) }
             .to_h
  end

  ##
  # Parse a conventional commit message
  #
  # @param subject [String] Commit subject line
  # @return [Array] [type, scope, description, breaking]
  def parse_conventional_commit(subject)
    # Handle merge commits from pull requests
    if subject.start_with?('Merge pull request')
      # Extract PR info and try to parse meaningful content
      pr_match = subject.match(/Merge pull request #(\d+) from .+\/(.+)/)
      if pr_match
        branch_name = pr_match[2]
        # Try to infer type from branch name (feature/fix/etc)
        if branch_name.match(/^(feature|feat)\//)
          return ['feat', nil, "Merge #{branch_name}", false]
        elsif branch_name.match(/^(fix|bugfix|hotfix)\//)
          return ['fix', nil, "Merge #{branch_name}", false]
        elsif branch_name.match(/^chore\//)
          return ['chore', nil, "Merge #{branch_name}", false]
        else
          return ['merge', nil, "Merge #{branch_name}", false]
        end
      end
      return ['merge', nil, subject, false]
    end

    # Match conventional commit format: type(scope): description
    match = subject.match(/^(\w+)(?:\(([^)]+)\))?(!)?: (.+)$/)

    if match
      type = match[1].downcase
      scope = match[2]
      breaking_marker = match[3] == '!'
      description = match[4]

      # Check for BREAKING CHANGE in description
      breaking = breaking_marker || description.include?('BREAKING CHANGE')

      [type, scope, description, breaking]
    else
      # Fallback for non-conventional commits
      ['other', nil, subject, false]
    end
  end

  ##
  # Determine if a commit should be skipped
  #
  # @param type [String] Commit type
  # @param commit [Hash] Commit information
  # @return [Boolean] true if commit should be skipped
  def should_skip_commit?(type, commit)
    # Skip certain types if configured
    skip_types = options[:skip_types] || []
    skip_types.include?(type)
  end

  ##
  # Get priority for category ordering
  #
  # @param category [String] Category name
  # @return [Integer] Priority (lower = higher priority)
  def category_priority(category)
    priorities = {
      'Breaking Changes' => 1,
      'Hotfixes' => 2,
      'Added' => 3,
      'Changed' => 4,
      'Fixed' => 5,
      'Deprecated' => 6,
      'Removed' => 7,
      'Security' => 8,
      'Performance' => 9,
      'Documentation' => 10,
      'Tests' => 11,
      'CI/CD' => 12,
      'Build' => 13,
      'Maintenance' => 14,
      'Other' => 15
    }
    priorities[category] || 99
  end

  ##
  # Determine the version bump type based on commits
  #
  # @param commits [Array<Hash>] Array of commits
  # @return [Symbol] :major, :minor, or :patch
  def determine_version_bump(commits)
    has_breaking = commits.any? do |commit|
      _, _, _, breaking = parse_conventional_commit(commit[:subject])
      breaking || commit[:body].include?('BREAKING CHANGE')
    end

    return :major if has_breaking

    has_features = commits.any? do |commit|
      type, _, _, _ = parse_conventional_commit(commit[:subject])
      type == 'feat'
    end

    has_features ? :minor : :patch
  end

  ##
  # Preview the changelog without writing to file
  #
  # @param categorized_commits [Hash] Commits grouped by category
  # @param version_bump [Symbol] Type of version bump
  def preview_changelog(categorized_commits, version_bump)
    puts "\n" + "="*50
    puts "CHANGELOG PREVIEW (#{version_bump.upcase} BUMP)"
    puts "="*50
    puts
    puts generate_changelog_content(categorized_commits)
  end

  ##
  # Update the CHANGELOG.md file
  #
  # @param categorized_commits [Hash] Commits grouped by category
  # @param version_bump [Symbol] Type of version bump
  def update_changelog(categorized_commits, version_bump)
    current_content = File.read(CHANGELOG_PATH)
    new_content = generate_changelog_content(categorized_commits)

    # Find the position to insert new content (after ## [Unreleased])
    unreleased_pattern = /^## \[Unreleased\]\s*\n/
    match = current_content.match(unreleased_pattern)

    unless match
      # If no [Unreleased] section exists, add after the main header
      header_pattern = /^# Changelog\s*\n/
      header_match = current_content.match(header_pattern)

      if header_match
        insertion_point = header_match.end(0)
        # Insert unreleased section and new release
        updated_content = current_content[0...insertion_point] +
                         "\n## [Unreleased]\n\n" +
                         new_content +
                         "\n" +
                         current_content[insertion_point..-1]
      else
        # Prepend to the entire file
        updated_content = new_content + "\n\n" + current_content
      end
    else
      # Insert new release section after the unreleased section
      insertion_point = match.end(0)

      updated_content = current_content[0...insertion_point] +
                       "\n" +
                       new_content +
                       "\n" +
                       current_content[insertion_point..-1]
    end

    # Write back to file
    File.write(CHANGELOG_PATH, updated_content)
  end

  ##
  # Generate changelog content for the new release
  #
  # @param categorized_commits [Hash] Commits grouped by category
  # @return [String] Formatted changelog content
  def generate_changelog_content(categorized_commits)
    content = []
    content << "## [#{version_string}] - #{Date.today.strftime('%Y-%m-%d')}"
    content << ""

    if categorized_commits.empty?
      content << "### Changed"
      content << "- Minor improvements and bug fixes"
      content << ""
    else
      categorized_commits.each do |category, commits|
        content << "### #{category}"
        content << ""

        commits.each do |commit_info|
          line = format_changelog_line(commit_info)
          content << line if line
        end

        content << ""
      end
    end

    content.join("\n")
  end

  ##
  # Format a single changelog line
  #
  # @param commit_info [Hash] Commit information
  # @return [String, nil] Formatted changelog line
  def format_changelog_line(commit_info)
    description = commit_info[:description]
    scope = commit_info[:scope]

    # Use original commit description or enhanced description
    text = description || commit_info.dig(:commit, :subject) || 'Unknown change'

    # Clean up text - remove conventional commit prefix if it exists
    text = text.gsub(/^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|hotfix):\s*/i, '')

    # Get commit hash (short form)
    commit_hash = commit_info.dig(:commit, :hash)
    short_hash = commit_hash ? commit_hash[0..7] : nil

    # Format the line
    line = "- #{text.capitalize}"
    line += " (#{scope})" if scope && !scope.empty?

    # Add commit link if repository URL is available
    if options[:include_commit_links] && repository_url && short_hash && commit_hash
      line += " ([#{short_hash}](#{repository_url}/commit/#{commit_hash}))"
    elsif short_hash
      line += " (#{short_hash})"
    end

    # Add breaking change marker
    if commit_info[:breaking]
      line = "- **BREAKING**: #{text.capitalize}"
      if options[:include_commit_links] && repository_url && short_hash && commit_hash
        line += " ([#{short_hash}](#{repository_url}/commit/#{commit_hash}))"
      elsif short_hash
        line += " (#{short_hash})"
      end
    end

    line
  end

end

##
# Command line interface
class CLI
  def self.run(args = ARGV)
    options = {}

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Automatic Changelog Generator"
      opts.separator ""
      opts.separator "This script generates changelog entries from git commits"
      opts.separator "following conventional commit format and Keep a Changelog style."
      opts.separator ""
      opts.separator "Requirements:"
      opts.separator "- Git repository with existing tags"
      opts.separator "- CHANGELOG.md file (will be created if missing)"
      opts.separator ""

      opts.on("-v", "--version VERSION", "Version to generate changelog for (e.g., 1.2.3 or v1.2.3)") do |version|
        options[:version] = version
      end

      opts.on("-d", "--dry-run", "Preview changes without modifying files") do
        options[:dry_run] = true
      end

      opts.on("-f", "--force", "Proceed even with uncommitted changes") do
        options[:force] = true
      end

      opts.on("--[no-]links", "Include/exclude commit links (default: include)") do |links|
        options[:include_commit_links] = links
      end

      opts.on("--debug", "Enable debug output") do
        options[:debug] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit 0
      end

      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  #{$0} --version 1.2.3              # Generate changelog for version 1.2.3"
      opts.separator "  #{$0} --version v1.2.3 --dry-run   # Preview without changes"
      opts.separator "  #{$0} --version 1.2.3 --force      # Ignore uncommitted changes"
      opts.separator "  #{$0} --version 1.2.3 --no-links   # Without commit links"
    end

    begin
      parser.parse!(args)

      unless options[:version]
        puts "Error: Version is required. Use --version flag."
        puts parser
        exit 1
      end

      generator = ChangelogGenerator.new(options)
      success = generator.generate!

      exit(success ? 0 : 1)

    rescue OptionParser::InvalidOption => e
      puts "Error: #{e.message}"
      puts parser
      exit 1
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end
end

# Run the CLI if this file is executed directly
if __FILE__ == $0
  CLI.run
end
