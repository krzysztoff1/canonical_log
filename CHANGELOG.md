# Changelog

## [1.0.0] - 2026-03-05

### Changed
- Refactored emit logic into shared `CanonicalLog::Emitter` — Sidekiq integration now applies sampling and formatting consistently

### Added
- `request_size_bytes` and `response_size_bytes` fields in middleware — tracks request/response body sizes from `Content-Length` headers
- Automatic OpenTelemetry `trace_id`/`span_id` injection when `opentelemetry-api` is present
- `enabled` config option (default: `true` in production, `false` in development/test) — master on/off switch for canonical logging, checked at runtime so it's toggleable per-request. Without Rails, defaults to `true`.
- `suppress_rails_logging` config option (default: `false`) — silences Rails' built-in ActionController and ActionView log subscribers when canonical log is active
- `pretty` config option (default: `false`) — pretty-prints JSON with ANSI syntax highlighting (cyan keys, green strings, yellow numbers, magenta booleans, gray nulls)
- `CanonicalLog::Formatters::Pretty` module for colorized JSON formatting
- `CanonicalLog::RailsLogSuppressor` module to suppress default Rails request logging
- Generator template now includes commented environment-based configuration examples at the top

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
