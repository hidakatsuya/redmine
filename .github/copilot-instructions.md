# Redmine Development Instructions

Redmine is a flexible project management web application written using Ruby on Rails framework. It provides issue tracking, project wikis, forums, calendar, Gantt charts, and time tracking functionality.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap, Build, and Test the Repository

**Prerequisites:**
- Ruby >= 3.2.0, < 3.5.0 (Ruby 3.2.3 is confirmed working)
- A database: MySQL 8+, PostgreSQL 14+, SQLite3 3.11+, or SQLServer 2012+
- Bundler gem manager
- Node.js and Yarn for CSS linting

**CRITICAL TIMING WARNINGS:**
- Bundle install takes ~1.5 minutes. NEVER CANCEL. Set timeout to 5+ minutes.
- Database migration takes ~5 seconds but may vary. NEVER CANCEL. Set timeout to 10+ minutes.
- Asset compilation takes ~2 seconds. Set timeout to 5+ minutes.
- Full test suite takes ~4.5 minutes. NEVER CANCEL. Set timeout to 15+ minutes.
- RuboCop linting takes ~33 seconds. Set timeout to 5+ minutes.

**Setup Commands:**
1. Install bundler: `sudo gem install bundler` (takes ~3 seconds)
2. Install Ruby dependencies: `sudo bundle install --without development test` (takes ~1.5 minutes)
3. Install Node dependencies: `yarn install` (takes ~13 seconds)
4. Create database configuration:
   ```bash
   cp config/database.yml.example config/database.yml
   # Edit to match your database setup, or use SQLite3 for development:
   ```
   Example SQLite3 config:
   ```yaml
   production:
     adapter: sqlite3
     database: db/redmine.sqlite3
   development:
     adapter: sqlite3
     database: db/redmine_development.sqlite3
   test:
     adapter: sqlite3
     database: db/redmine_test.sqlite3
   ```
5. Generate session secret: `sudo bundle exec rake generate_secret_token` (takes ~2 seconds)
6. Run database migration: `sudo bundle exec rake db:migrate RAILS_ENV="production"` (takes ~5 seconds)
7. Load sample data: `bin/rails db:fixtures:load RAILS_ENV=production` (takes ~3 seconds)
8. Compile assets: `sudo bundle exec rake assets:precompile RAILS_ENV="production"` (takes ~2 seconds)

**Run the Application:**
- Install test dependencies for server: `sudo bundle install --with test` (takes ~27 seconds)
- Start server: `sudo bundle exec rails server -e production -p 3000`
- Access at: `http://localhost:3000`
- Default admin login: username=`admin`, password=`admin` (will require password change on first login)

**Run Tests:**
- Full test suite: `sudo bundle exec rails test RAILS_ENV=test` (takes ~4.5 minutes, 5432 tests, NEVER CANCEL)
- System tests: `bin/rails test:system` (requires Chrome/ChromeDriver)
- Autoload tests: `bin/rails test:autoload`

**Test Execution Methods - Reference GitHub Actions Workflows:**
For comprehensive test execution methods, always reference the GitHub Actions workflows:
- **Primary test workflow**: `.github/workflows/tests.yml` - Shows how tests are run across Ruby 3.2/3.3/3.4 with PostgreSQL/MySQL2/SQLite3
- **Environment setup**: `.github/actions/setup-redmine/action.yml` - Composite action that configures the complete test environment including:
  - System dependencies (ghostscript, gsfonts, locales, bzr, cvs)
  - ImageMagick policy configuration for PDF handling
  - Database configuration for different adapters
  - Ruby/bundler setup with caching
  - Test environment preparation with `ci:about`, `ci:setup`, `db:environment:set`

The CI workflows provide the authoritative reference for test execution commands and environment setup procedures.

**Run Linting:**
- Ruby code: `sudo bundle exec rubocop --parallel` (takes ~33 seconds, NEVER CANCEL)
- CSS files: `npx stylelint "app/assets/stylesheets/**/*.css"` (takes ~1 second)
- Security audit: `sudo bundle exec bundle audit check --update` (takes ~2 seconds)

## Implementation Guidelines

When writing new code, follow these style guidelines:

- **Hash notation**: Use `{ key: 'value' }` syntax for hashes
- **Modern Ruby syntax**: Use the latest Ruby syntax as long as RuboCop rules allow it and compatibility is maintained within supported Ruby versions
- **Code style**: Follow existing patterns in the codebase and ensure all changes pass RuboCop linting

## Validation

- ALWAYS run through at least one complete end-to-end scenario after making changes.
- Test the login flow by navigating to `http://localhost:3000`, clicking "Sign in", logging in with admin/admin, and verifying the home screen loads after password change.
- Always run `bundle exec rubocop --parallel` and `npx stylelint "app/assets/stylesheets/**/*.css"` before committing or the CI (.github/workflows/linters.yml) will fail.
- For local testing, use the latest environment only: Ruby 3.4 with SQLite3. The CI will handle testing across all supported versions.

## Common Issues and Workarounds

- **Permission Issues:** Use `sudo` for bundle and rake commands in sandboxed environments due to gem installation permission requirements.
- **Server Gem Missing:** Install test dependencies with `sudo bundle install --with test` to get Puma server gem.
- **Database Not Configured:** Copy `config/database.yml.example` to `config/database.yml` and configure for your database.
- **Missing ImageMagick/GhostScript:** Many tests will be skipped but core functionality works. Install with `sudo apt-get install imagemagick ghostscript` if needed.
- **Repository Tests Skipped:** SCM repository tests are skipped unless specific test repositories are configured (see doc/RUNNING_TESTS).

## Project Structure

**Key Directories:**
- `app/` - Rails application code (models, views, controllers, helpers, assets)
- `config/` - Configuration files (database, routes, initializers)
- `db/` - Database schema and migrations
- `lib/` - Library code and plugins
- `test/` - Test suite (unit, functional, integration, system tests)
- `plugins/` - Redmine plugins
- `public/` - Public web assets
- `.github/workflows/` - CI/CD configuration (tests.yml, linters.yml)

**Important Files:**
- `Gemfile` - Ruby dependencies
- `package.json` - Node.js dependencies for linting
- `config/database.yml.example` - Database configuration template
- `config/configuration.yml.example` - Application configuration template
- `doc/INSTALL` - Detailed installation instructions
- `README.rdoc` - Basic project information

## CI/CD Information

**GitHub Actions Workflows:**
- `.github/workflows/tests.yml` - Runs tests on Ruby 3.2/3.3/3.4 with PostgreSQL/MySQL2/SQLite3
- `.github/workflows/linters.yml` - Runs RuboCop, Stylelint, and Bundle Audit
- `.github/actions/setup-redmine/action.yml` - Composite action for CI environment setup

**Pre-commit Validation:**
Always run these commands before committing:
1. `bundle exec rubocop --parallel` - Ruby linting
2. `npx stylelint "app/assets/stylesheets/**/*.css"` - CSS linting  
3. `bundle exec bundle audit check --update` - Security audit
4. `bin/rails test` - Run test suite for critical changes

## Frequently Used Commands

**Development:**
- `bundle exec rails console` - Rails console for debugging
- `bundle exec rails server` - Start development server
- `bundle exec rake -T` - List all available rake tasks

**Database:**
- `bundle exec rake db:create` - Create database
- `bundle exec rake db:migrate` - Run migrations
- `bundle exec rake db:seed` - Load seed data (if available)

**Testing:**
- `bin/rails test test/unit/` - Run unit tests only
- `bin/rails test test/functional/` - Run functional tests only
- `bin/rails test test/integration/` - Run integration tests only

**Asset Management:**
- `bundle exec rake assets:precompile` - Compile assets
- `bundle exec rake assets:clean` - Remove old compiled assets
- `bundle exec rake assets:clobber` - Remove all compiled assets

**User Management:**
- Default admin user: username=`admin`, password=`admin`
- Access admin interface at `/admin` after login
- Change passwords at `/my/password`

## Redmine.org Patch Submission

**Important**: For issues that require patches to be submitted to redmine.org, include the following information in the pull request:

**Redmine.org Ticket Title:**
```
Add GitHub Copilot development instructions for improved coding agent support
```

**Redmine.org Ticket Content:**
```
This patch adds comprehensive GitHub Copilot instructions (/.github/copilot-instructions.md) to help coding agents work effectively with the Redmine codebase.

The instructions provide:
- Complete setup procedures with validated timing benchmarks
- Test execution methods referencing GitHub Actions workflows
- Development environment configuration and troubleshooting
- CI/CD integration details and validation procedures
- Project structure overview and common development patterns

This enhancement will improve development experience for contributors using AI coding assistants and ensure consistent development practices across the project.

The instructions are based on validated procedures and include references to existing CI workflows for authoritative test execution methods.
```