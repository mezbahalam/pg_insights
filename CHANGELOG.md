# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - YYYY-MM-DD

### Added
- Initial release of `pg_insights`.
- Dashboard to view and run PostgreSQL diagnostic queries.
- Pre-defined queries for common performance and health checks.
- Ability to write, save, and manage custom SQL queries.
- Fetches and displays table names for easier query writing.
- Renders query results in a table view.
- Uses `chartkick` for data visualization.
- Enforces read-only queries with statement timeouts for security. 