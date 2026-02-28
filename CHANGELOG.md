# Changelog

## [0.1.3] - 2026-02-28

### Added
- Null sink (`CanonicalLog::Sinks::Null`) — silent no-op sink for use in tests
- Tests default to Null sink via `spec_helper.rb` to suppress log output unless explicitly configured

## [0.1.2] - 2026-02-21

### Added
- Sidekiq integration (`CanonicalLog::Integrations::Sidekiq`) — server middleware that creates canonical log events for background jobs with job class, queue, and JID fields
- Error enrichment concern (`CanonicalLog::Integrations::ErrorEnrichment`) — `around_action` that captures rescued error class and message into the canonical log event
- Auto-generated `message` field in middleware (e.g. `GET /users 200`) when not explicitly set

## [0.1.0] - 2025-01-01

### Added
- Initial release
- Rack middleware for canonical log line emission
- ActiveRecord and ActionController subscribers
- Configurable sinks (stdout, Rails logger)
- Sampling support
- Path ignoring
