# CanonicalLog

[![Gem Version](https://badge.fury.io/rb/canonical_log.svg)](https://badge.fury.io/rb/canonical_log)

One structured JSON log line per request.
Inspired by:

- https://loggingsucks.com
- https://brandur.org/canonical-log-lines
- https://stripe.com/blog/canonical-log-lines

## Why wide events?

Traditional logging scatters information across multiple lines:

```
Started GET "/api/users/123" for 127.0.0.1
Processing by UsersController#show as JSON
  User Load (2.1ms)  SELECT "users".* FROM "users" WHERE "users"."id" = 123
Completed 200 OK in 45ms (Views: 0.1ms | ActiveRecord: 2.1ms)
```

Wide event logging captures everything in **one queryable event**:

```json
{
  "timestamp": "2026-02-19T14:23:01.123Z",
  "duration_ms": 45.12,
  "request_id": "abc-123-def",
  "http_method": "GET",
  "path": "/api/users/123",
  "http_status": 200,
  "controller": "UsersController",
  "action": "show",
  "db_query_count": 1,
  "db_total_time_ms": 2.1,
  "level": "info",
  "message": "GET /api/users/123 200",
  "user": { "id": 42, "email": "user@example.com" }
}
```

Query by any field. Aggregate easily. No correlation needed.

## AI-assisted setup

Use the ready-made prompt in [AI_PROMPT.md](AI_PROMPT.md) to have an AI coding assistant (Claude, Cursor, Copilot, etc.) add canonical logging to your app. Copy the prompt, paste it into your assistant, and it will walk through installation, configuration, and instrumenting your key actions.

## Example output

Successful request with categorized context:

```json
{
  "timestamp": "2026-02-19T14:23:01.123Z",
  "duration_ms": 142.35,
  "request_id": "abc-123-def",
  "http_method": "POST",
  "path": "/orders",
  "query_string": null,
  "remote_ip": "192.168.1.42",
  "user_agent": "Mozilla/5.0...",
  "content_type": "application/json",
  "http_status": 201,
  "controller": "OrdersController",
  "action": "create",
  "params": { "item_id": "42", "quantity": "2" },
  "format": "json",
  "view_runtime_ms": 12.35,
  "db_runtime_ms": 45.68,
  "db_query_count": 8,
  "db_total_time_ms": 45.67,
  "level": "info",
  "message": "POST /orders 201",
  "user": { "id": 7891, "email": "buyer@example.com" },
  "business": { "order_id": 12345, "endpoint": "create_order" }
}
```

Error with structured error object:

```json
{
  "timestamp": "2026-02-19T14:25:12.456Z",
  "duration_ms": 83.21,
  "request_id": "fed-456-cba",
  "http_method": "POST",
  "path": "/payments",
  "http_status": 500,
  "controller": "PaymentsController",
  "action": "create",
  "params": { "order_id": "123", "token": "[FILTERED]" },
  "db_query_count": 3,
  "db_total_time_ms": 12.45,
  "error": {
    "class": "Stripe::CardError",
    "message": "Your card was declined.",
    "backtrace": ["app/services/payment.rb:42:in `charge!'", "..."]
  },
  "level": "error",
  "message": "POST /payments 500",
  "user": { "id": 7891, "email": "buyer@example.com" }
}
```

Request with slow queries:

```json
{
  "timestamp": "2026-02-19T14:30:05.789Z",
  "duration_ms": 1243.56,
  "request_id": "aaa-789-bbb",
  "http_method": "GET",
  "path": "/admin/reports",
  "query_string": "range=last_year",
  "http_status": 200,
  "controller": "Admin::ReportsController",
  "action": "index",
  "db_query_count": 14,
  "db_total_time_ms": 1102.33,
  "slow_queries": [
    {
      "sql": "SELECT orders.*, customers.name FROM orders INNER JOIN customers ON ...",
      "duration_ms": 812.45,
      "name": "Order Load"
    }
  ],
  "level": "info",
  "message": "GET /admin/reports 200",
  "user": { "id": 42, "email": "admin@example.com" }
}
```

## Installation

Add to your Gemfile:

```ruby
gem "canonical_log"
```

Then run:

```bash
bundle install
rails generate canonical_log:install
```

The generator creates `config/initializers/canonical_log.rb` with documented defaults.

### Non-Rails Rack apps

Add the middleware manually:

```ruby
use CanonicalLog::Middleware
```

## How it works

A thread-local `Event` object accumulates fields during the request. Rack middleware bookends the lifecycle: initializes at the start, emits at the end. Rails subscribers automatically enrich the event with controller, query, and timing data.

```
                         REQUEST LIFECYCLE
 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─

  POST /orders ──►  Middleware.init!
                    Creates Event object
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  Rack Middleware (automatic)                    │
                    │  │  request_id, http_method, path, query_string,  │
                    │  │  remote_ip, user_agent, content_type,           │
                    │  │  request_size_bytes, response_size_bytes        │
                    │  └─────────────────────────────────────────────────┘
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  Action Controller Subscriber (automatic)      │
                    │  │  controller, action, format, params (filtered),│
                    │  │  view_runtime_ms, db_runtime_ms                │
                    │  └─────────────────────────────────────────────────┘
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  Active Record Subscriber (automatic)          │
                    │  │  db_query_count, db_total_time_ms,             │
                    │  │  slow_queries (above threshold)                │
                    │  └─────────────────────────────────────────────────┘
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  Warden/Devise Detection (automatic)           │
                    │  │  user: { id, email }                           │
                    │  └─────────────────────────────────────────────────┘
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  Your Code (manual — controllers, services)    │
                    │  │                                                 │
                    │  │  CanonicalLog.context(:business, order_id: 123)│
                    │  │  CanonicalLog.add(checkout_step: "payment")    │
                    │  │  CanonicalLog.increment(:external_api_calls)   │
                    │  │  CanonicalLog.add_error(e, code: "declined")   │
                    │  └─────────────────────────────────────────────────┘
                    │
                    │  ┌─────────────────────────────────────────────────┐
                    ├──│  before_emit Hook (automatic)                  │
                    │  │  Last chance to enrich (app_version, region)   │
                    │  └─────────────────────────────────────────────────┘
                    │
                    ▼
               Middleware.emit!
               ┌────────────────────────────────────┐
               │  Sampling decision (tail sampling) │
               │  - Always keeps errors (5xx)       │
               │  - Always keeps slow requests      │
               │  - Samples the rest at sample_rate  │
               └──────────────┬─────────────────────┘
                              │
                              ▼
                    ONE JSON log line ──►  Sinks
                                          (stdout, Rails logger, custom)

 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
```

## Usage

### Flat fields

Add context from anywhere in your application code:

```ruby
# Add multiple fields at once
CanonicalLog.add(order_id: 123, checkout_step: "payment")

# Set a single field
CanonicalLog.set(:checkout_step, "payment")

# Increment a counter
CanonicalLog.increment(:external_api_calls)

# Append to an array
CanonicalLog.append(:feature_flags, "new_checkout")
```

### Categorized context

Group related fields into categories for cleaner structure:

```ruby
# User context
CanonicalLog.context(:user, id: 42, tier: "premium", account_age_days: 365)

# Business logic context
CanonicalLog.context(:business, endpoint: "create_order", order_id: 123)

# Infrastructure context
CanonicalLog.context(:infra, region: "eu-central-1", k8s_pod: "api-abc123")

# Service metadata
CanonicalLog.context(:service, version: "1.2.3", git_sha: "abc123")
```

Available categories: `:user`, `:business`, `:infra`, `:service`.

### Structured errors

```ruby
begin
  process_payment
rescue Stripe::CardError => e
  CanonicalLog.add_error(e, code: "card_declined", retriable: false)
  head :unprocessable_entity
end
```

Produces:

```json
{
  "error": {
    "class": "Stripe::CardError",
    "message": "Your card was declined.",
    "backtrace": ["app/services/payment.rb:42:in `charge!'", "..."],
    "code": "card_declined",
    "retriable": false
  }
}
```

Backtrace includes up to 5 lines by default (configurable via `error_backtrace_lines`).

All calls are safe to use even when no event is active (they silently no-op).

## Configuration

```ruby
CanonicalLog.configure do |config|
  # Master on/off switch.
  # Defaults to true in production (or when Rails is not defined), false otherwise.
  # Checked at runtime, so it's toggleable per-request.
  # config.enabled = true

  # Suppress Rails' default ActionController/ActionView log subscribers (default: false).
  # Useful when canonical log replaces the default request logging.
  # config.suppress_rails_logging = true

  # Pretty-print JSON with ANSI colors (default: false).
  # Great for development — cyan keys, green strings, yellow numbers.
  # config.pretty = true

  # Where to write log lines.
  # :auto (default) -> Stdout (JSON to $stdout).
  # Pass any object responding to #write(json_string), or an array of them.
  config.sinks = :auto

  # Output format: :json (default), :pretty, or :logfmt.
  # config.format = :json

  # Parameter keys replaced with [FILTERED] in output.
  config.param_filter_keys = %w[password password_confirmation token secret secret_key api_key access_token credit_card card_number cvv ssn authorization]

  # Filter literal values from SQL in slow_queries (default: true).
  # config.filter_sql_literals = true

  # Filter sensitive params from query strings (default: true).
  # config.filter_query_string = true

  # SQL queries slower than this (ms) are captured individually.
  config.slow_query_threshold_ms = 100.0

  # Paths to skip entirely (no log line emitted).
  # Strings match by prefix, Regexps by pattern.
  config.ignored_paths = ["/health", "/assets", %r{\A/packs}]

  # Fields merged into every event (e.g., app name, environment).
  # config.default_fields = { app: "myapp", env: Rails.env }

  # Number of backtrace lines included in error objects (default: 5, 0 to disable).
  # config.error_backtrace_lines = 5

  # --- Sampling ---

  # Fraction of requests to log (1.0 = everything, 0.05 = 5%).
  # Errors and slow requests are always logged regardless of sample rate.
  config.sample_rate = 1.0

  # Requests slower than this (ms) are always logged, even when sampled out.
  config.slow_request_threshold_ms = 2000.0

  # Custom sampling function (overrides sample_rate).
  # Receives (event_hash, config) -> boolean.
  config.sampling = ->(event, _config) {
    return true if event[:http_status].to_i >= 500
    return true if event[:duration_ms].to_f > 1000
    rand < 0.1  # 10% of the rest
  }

  # --- User context ---

  # Extract user context from each request.
  # Receives the Rack env hash (after the request completes, so Warden is available).
  # When not set and Warden/Devise is detected, user_id and user_email
  # are captured automatically into the :user category.
  config.user_context = ->(env) {
    user = env['warden']&.user
    if user
      { user_id: user.id, role: user.role, org_id: user.organization_id }
    else
      {}
    end
  }

  # --- Log level ---

  # Custom log level resolver (overrides default status-based logic).
  # Default: 5xx/error -> :error, 4xx -> :warn, else -> :info.
  # config.log_level_resolver = ->(event_hash) {
  #   event_hash[:http_status].to_i >= 500 ? :error : :info
  # }

  # Hook called just before the event is serialized and emitted.
  config.before_emit = ->(event) {
    event.set(:app_version, ENV["APP_VERSION"])
    event.context(:infra, region: ENV["AWS_REGION"])
  }
end
```

## Sampling

By default, every request is logged (`sample_rate = 1.0`). In production with high traffic, enable sampling to reduce volume while keeping important events:

```ruby
CanonicalLog.configure do |config|
  config.sample_rate = 0.05              # Log 5% of normal traffic
  config.slow_request_threshold_ms = 1000 # Always log requests > 1s
end
```

The default sampling strategy:

- **Always keeps** requests with HTTP status >= 500
- **Always keeps** requests with an error
- **Always keeps** requests slower than `slow_request_threshold_ms`
- **Samples** the rest at `sample_rate`

Pass a custom `sampling` proc for full control.

## Environment-based configuration

By default, canonical logging is enabled only in production (disabled in development and test). You can override this and tune other options per environment:

```ruby
CanonicalLog.configure do |config|
  # Already defaults to production-only, but you can override:
  config.enabled = true # enable everywhere

  # Suppress Rails' default request logs when canonical log is active:
  config.suppress_rails_logging = Rails.env.production?

  # Pretty-print with colors in development:
  config.pretty = Rails.env.development?
end
```

| Option                   | Default                                 | Description                                                                                                                                                            |
| ------------------------ | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`                | `true` in production, `false` otherwise | Master on/off switch. When `false`, middleware passes through and subscribers no-op. Checked at runtime, not boot time. Without Rails, defaults to `true`.             |
| `suppress_rails_logging` | `false`                                 | Silences Rails' built-in `ActionController::LogSubscriber` and `ActionView::LogSubscriber` by redirecting their loggers to `/dev/null`.                                |
| `pretty`                 | `false`                                 | Shortcut for `format = :pretty`. Emits indented JSON with ANSI color codes: cyan for keys, green for strings, yellow for numbers, magenta for booleans, gray for null. |
| `format`                 | `:json`                                 | Output format: `:json`, `:pretty`, or `:logfmt`.                                                                                                                       |
| `default_fields`         | `{}`                                    | Hash merged into every event before emission. Useful for app name, environment, deploy version.                                                                        |
| `filter_sql_literals`    | `true`                                  | Replaces literal values in SQL captured in `slow_queries` with `?` placeholders.                                                                                       |
| `filter_query_string`    | `true`                                  | Filters sensitive parameters from the `query_string` field using `param_filter_keys`.                                                                                  |
| `error_backtrace_lines`  | `5`                                     | Number of backtrace lines included in structured errors. Set to `0` to disable.                                                                                        |
| `log_level_resolver`     | `nil`                                   | Custom proc `(event_hash) -> :info/:warn/:error`. Default logic: 5xx/error → `:error`, 4xx → `:warn`, else → `:info`.                                                  |

## What's captured automatically

### Via Rack middleware

| Field                 | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| `timestamp`           | ISO 8601 UTC timestamp                                         |
| `duration_ms`         | Total request time (monotonic clock)                           |
| `request_id`          | From `X-Request-ID` header, Action Dispatch, or generated UUID |
| `http_method`         | GET, POST, etc.                                                |
| `path`                | Request path                                                   |
| `query_string`        | Raw query string (if present)                                  |
| `remote_ip`           | Client IP (respects `X-Forwarded-For`)                         |
| `user_agent`          | Client user agent string                                       |
| `content_type`        | Request content type                                           |
| `request_size_bytes`  | Request body size from `Content-Length` header                 |
| `http_status`         | Response status code                                           |
| `response_size_bytes` | Response body size from `Content-Length` header                |
| `trace_id`            | OpenTelemetry trace ID (when `opentelemetry-api` is loaded)    |
| `span_id`             | OpenTelemetry span ID (when `opentelemetry-api` is loaded)     |
| `error`               | Structured error object (on unhandled errors)                  |
| `user`                | Auto-detected from Warden/Devise (id, email)                   |
| `level`               | Log level: `info`, `warn` (4xx), or `error` (5xx/exception)    |
| `message`             | Auto-built summary, e.g. `"GET /users 200"`                    |

### Via Action Controller subscriber

| Field             | Description                        |
| ----------------- | ---------------------------------- |
| `controller`      | Controller class name              |
| `action`          | Action name                        |
| `format`          | Response format (html, json, etc.) |
| `params`          | Filtered request parameters        |
| `view_runtime_ms` | Time spent rendering views         |
| `db_runtime_ms`   | Time spent in database             |

### Via Active Record subscriber

| Field              | Description                              |
| ------------------ | ---------------------------------------- |
| `db_query_count`   | Total SQL queries executed               |
| `db_total_time_ms` | Cumulative query time                    |
| `slow_queries`     | Array of queries exceeding the threshold |

### Via ActiveSupport Cache subscriber

| Field                 | Description                     |
| --------------------- | ------------------------------- |
| `cache_read_count`    | Total cache reads               |
| `cache_write_count`   | Total cache writes              |
| `cache_hit_count`     | Cache hits                      |
| `cache_miss_count`    | Cache misses                    |
| `cache_total_time_ms` | Cumulative cache operation time |

### Via ActiveJob subscriber

Each job emits its own canonical log line with:

| Field         | Description          |
| ------------- | -------------------- |
| `job_class`   | Job class name       |
| `queue`       | Queue name           |
| `job_id`      | Job ID               |
| `executions`  | Number of executions |
| `priority`    | Job priority         |
| `duration_ms` | Job execution time   |

## Integrations

### Sidekiq

Add the server middleware for per-job canonical log lines:

```ruby
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add CanonicalLog::Integrations::Sidekiq
  end
end
```

Each job emits its own log line with `job_class`, `queue`, `jid`, timing, and any errors.

### OpenTelemetry

When the `opentelemetry-api` gem is loaded, `trace_id` and `span_id` are automatically injected into every canonical log line from the current span context. No configuration needed — if OpenTelemetry isn't present, nothing happens.

### Error enrichment

Opt-in concern that captures rescued exceptions in controllers:

```ruby
class ApplicationController < ActionController::Base
  include CanonicalLog::Integrations::ErrorEnrichment
end
```

### Logfmt formatter

For `logfmt`-style output instead of JSON:

```ruby
CanonicalLog.configure do |config|
  config.format = :logfmt
end
```

Produces:

```
timestamp=2026-02-19T14:23:01.123Z duration_ms=45.12 http_method=GET path=/api/users/123 http_status=200 level=info
```

Nested hashes are flattened with dots (e.g., `user.id=42`). Values with spaces or special characters are quoted.

### Custom sinks

Any object with a `#write(json_string)` method works as a sink:

```ruby
class DatadogSink < CanonicalLog::Sinks::Base
  def write(json_string)
    # Send to Datadog, Splunk, ClickHouse, BigQuery, etc.
  end
end

CanonicalLog.configure do |config|
  config.sinks = [
    CanonicalLog::Sinks::Stdout.new,
    DatadogSink.new
  ]
end
```

## Event structure

A complete wide event contains:

```json
{
  "timestamp": "2026-02-19T14:23:45.612Z",
  "duration_ms": 124,
  "request_id": "req_8bf7ec2d",
  "http_method": "GET",
  "path": "/api/users/123",
  "query_string": "filter=active",
  "remote_ip": "192.168.1.42",
  "user_agent": "Mozilla/5.0...",
  "content_type": null,
  "http_status": 200,
  "controller": "Api::V1::UsersController",
  "action": "show",
  "format": "*/*",
  "params": { "filter": "active" },
  "view_runtime_ms": 0.12,
  "db_runtime_ms": 18.44,
  "db_query_count": 3,
  "db_total_time_ms": 18.44,
  "level": "info",
  "message": "GET /api/users/123 200",
  "user": { "id": 123, "email": "user@example.com", "tier": "premium" },
  "business": { "endpoint": "get_user", "feature_flags": ["new_ui"] },
  "infra": { "region": "eu-central-1" },
  "service": { "version": "1.2.3", "git_sha": "abc123" }
}
```

## Design decisions

- **Thread.current** for storage -- no external dependencies, works with Puma/Unicorn/Passenger
- **Mutex in Event** -- protects against concurrent access from spawned threads
- **Middleware at position 0** -- outermost position for accurate full-request timing
- **ActiveSupport::Notifications** -- subscribes to existing instrumentation instead of monkey-patching
- **Sampling after collection** -- all fields are gathered first, then the sampling decision is made (tail sampling), so errors and slow requests are never lost
- **Emit errors never crash requests** -- rescued and sent to `warn`
- **Safe nil context** -- all public methods no-op when called outside a request lifecycle
- **Auto Warden/Devise detection** -- user context is captured automatically when no custom `user_context` is configured

## Requirements

- Ruby >= 3.0
- Rack >= 2.0
- ActiveSupport >= 6.0

## License

MIT
