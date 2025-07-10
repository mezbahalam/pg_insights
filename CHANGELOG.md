# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2025-01-15

### Fixed
- **Results Table CSS Loading**: Fixed broken table design in query results
  - Added explicit stylesheet includes for `pg_insights/results.css` and `pg_insights/health.css`
  - Added explicit JavaScript includes for `pg_insights/results.js` and `pg_insights/health.js`
  - Resolved issue where `require_tree .` directive wasn't loading all CSS files properly
  - Tables now display with proper styling, fonts, colors, and responsive design
  - Fixed view toggle functionality and table interactive features

## [0.3.0] - 2025-07-07

### Fixed
- **ActiveJob Queue Naming**: Fixed confusing queue logging that showed lambda object references instead of actual queue names
  - Changed from lambda syntax `queue_as -> { }` to block syntax `queue_as do ... end` in ApplicationJob
  - Logs now clearly show the actual queue name (e.g., `pg_insights_health`) instead of `#<Proc:0x000000017e1c6b30...>`
  - Removed duplicate `queue_as` declarations from individual job classes - they now properly inherit from ApplicationJob
  - Improved debugging experience and monitoring clarity for background jobs
- **Timeline Data Fetching and Ordering**: Fixed timeline data bugs introduced during database optimization
  - Fixed incomplete data issue where timeline was limited to 90 snapshots before filtering to 30 days
  - Fixed incorrect ordering where timeline charts displayed backwards (newest-first instead of oldest-first)
  - Timeline data now correctly fetches ALL snapshots from last 30 days with proper chronological ordering

### Improved
- **Database Query Optimization**: Optimized parameter changes queries to avoid redundant calls
  - Enhanced query reuse patterns in timeline data collection
  - Maintains performance improvements while preserving correct data fetching behavior

### Technical Improvements
- Cleaner ActiveJob inheritance pattern with centralized queue configuration
- Better code organization with reduced duplication
- Proper timeline data handling with correct ordering and complete data sets

## [0.2.1] - 2025-07-04

### Fixed
- **Installation Generator**: Fixed `rails generate pg_insights:install` command that was failing with "Could not find migration files" error
  - Migration template files were not being packaged with the gem due to incorrect file paths
  - Moved migration files from `db/migrate/` to `lib/generators/pg_insights/templates/db/migrate/` 
  - Updated generator source path to correctly locate template files
  - This ensures the install generator works properly for all users installing the gem

## [0.2.0] - 2025-07-03

### Added
- **Timeline Feature**: Complete database monitoring and historical tracking system
  - Database snapshot collection with automatic scheduling via `DatabaseSnapshotJob`
  - Parameter change detection across PostgreSQL configurations
  - Performance metrics tracking (cache hit rates, query times, connection counts)
  - Historical data comparison between any two time periods
  - Timeline view with visual charts and trend analysis
- **Enhanced Health Check System**:
  - Database snapshot collection as a new health check type
  - Comprehensive metadata collection (PostgreSQL version, extensions, database size)
  - Enhanced performance metrics collection
  - Parameter change detection and categorization
- **Export Capabilities**:
  - CSV export for timeline data analysis
  - JSON export for programmatic data access
- **Configuration Enhancements**:
  - Snapshot frequency configuration (`snapshot_frequency`)
  - Snapshot retention policy (`snapshot_retention_days`)
  - Master switches for snapshot functionality
- **New Rake Tasks**:
  - `rails pg_insights:collect_snapshot` - Collect database snapshot immediately
  - `rails pg_insights:start_snapshots` - Start recurring snapshot collection
  - `rails pg_insights:snapshot_status` - Check snapshot configuration and status
  - `rails pg_insights:cleanup_snapshots` - Clean up old snapshots based on retention policy
  - `rails pg_insights:reset` - Reset all PgInsights data (improved with better output)
  - `rails pg_insights:cleanup` - Clean up old health check results
  - `rails pg_insights:test_jobs` - Test background job functionality
  - `rails pg_insights:seed_timeline` - Generate fake timeline data for testing
  - `rails pg_insights:sample_data` - Generate sample health check data
- **Enhanced Navigation**: Timeline tab added to main navigation
- **Data Management**: Automatic cleanup of old snapshots based on retention policy

### Enhanced
- Health check model with extensive snapshot and comparison capabilities
- Health check service with database snapshot collection
- Install generator with improved guidance for timeline features
- Application layout with navigation for timeline feature

### Technical Improvements
- Proper parameter change type detection (increase/decrease/stable)
- Numeric value extraction for memory and size parameters
- Enhanced error handling in timeline controller
- Background job integration following established patterns
- Configurable snapshot intervals and retention
- Improved rake task organization and error handling
- Eliminated duplicate rake tasks and improved consistency
- Added backward compatibility aliases for existing rake tasks

## [0.1.0] - 2025-06-30

### Added
- Initial release of `pg_insights`.
- Dashboard to view and run PostgreSQL diagnostic queries.
- Pre-defined queries for common performance and health checks.
- Ability to write, save, and manage custom SQL queries.
- Fetches and displays table names for easier query writing.
- Renders query results in a table view.
- Uses `chartkick` for data visualization.
- Enforces read-only queries with statement timeouts for security. 