# Gem Packaging Plan

## Overview

Package Super8 as a Ruby gem for GitHub-based installation with standard gemspec, version management, and MIT licensing.

## Gem Metadata

- **Name**: `super8`
- **Version**: `0.0.1` (defined in `lib/super8/version.rb`)
- **Author**: John Cipriano
- **Email**: johnmikecip@gmail.com
- **Homepage**: https://github.com/johncip/super8
- **License**: MIT
- **Summary**: Record and replay ruby-odbc sessions for easier, more accurate testing.
- **Description**: Super 8 is a "vcr"-like library for recording and playing back ODBC interactions made with ruby-odbc, for use with automated testing. More accurate than manually mocking and less work than adding an ODBC-enabled server to your test stack.

## Files to Include/Exclude

- **Include**: `lib/`, `spec/`, `LICENSE`, `README.md`
- **Exclude**: `design/` (development documentation only)

## Steps

### 1. Create version file

Create `lib/super8/version.rb` defining `Super8::VERSION = "0.0.1"`, and require it in [lib/super8.rb](lib/super8.rb).

### 2. Create gemspec

Create `super8.gemspec` at root with:
- Metadata: name `super8`, version from `Super8::VERSION`, summary, authors, homepage pointing to GitHub repo, MIT license
- Runtime dependency: `odbc`
- Development dependencies: `rspec`, `fakefs`, `rake`
- Required Ruby version: `>= 3.1.0`

### 3. Add Gemfile

Add `Gemfile` sourcing rubygems.org and using `gemspec` to load dependencies from the gemspec.

### 4. Create Rakefile

Create `Rakefile` with RSpec test task (default) and optional gem build/install tasks.

### 5. Add supporting files

- `.ruby-version` file with `3.3.0` (or latest 3.3.x)
- `.gitignore` for `*.gem`, `pkg/`, and `Gemfile.lock`
- `LICENSE` file with MIT license text

### 6. Update README

Update [README.md](README.md) with:
- Installation instructions (git-based Gemfile entry)
- Basic usage example
- Requirements (Ruby 3.1+)
- License mention

## Version Management Strategy

- Start at version `0.0.1` to signal early alpha stage
- For internal development: point Gemfile at `branch: 'main'` and update via `bundle update super8`
- Version number can remain unchanged between commits when using branch-based installation
- When publishing to RubyGems: bump version → commit → tag → publish
- Use semantic versioning: anything before 1.0 has no stability guarantees