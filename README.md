# CanonicalLog

[![Gem Version](https://badge.fury.io/rb/canonical_log.svg)](https://badge.fury.io/rb/canonical_log)

One structured JSON log line per request. No more scattered `logger.info` calls.
Inspired by [Stripe's canonical log lines](https://stripe.com/blog/canonical-log-lines) and [wide event logging](https://loggingsucks.com).

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
    "message": "Your card was declined."
  },
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
                    │  │  remote_ip, user_agent, content_type            │
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
    "code": "card_declined",
    "retriable": false
  }
}
```

All calls are safe to use even when no event is active (they silently no-op).

## Configuration

```ruby
CanonicalLog.configure do |config|
  # Where to write log lines.
  # :auto (default) -> Stdout (JSON to $stdout).
  # Pass any object responding to #write(json_string), or an array of them.
  config.sinks = :auto

  # Parameter keys replaced with [FILTERED] in output.
  config.param_filter_keys = %w[password password_confirmation token secret]

  # SQL queries slower than this (ms) are captured individually.
  config.slow_query_threshold_ms = 100.0

  # Paths to skip entirely (no log line emitted).
  # Strings match by prefix, Regexps by pattern.
  config.ignored_paths = ["/health", "/assets", %r{\A/packs}]

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

## What's captured automatically

### Via Rack middleware

| Field | Description |
|-------|-------------|
| `timestamp` | ISO 8601 UTC timestamp |
| `duration_ms` | Total request time (monotonic clock) |
| `request_id` | From `X-Request-ID` header, Action Dispatch, or generated UUID |
| `http_method` | GET, POST, etc. |
| `path` | Request path |
| `query_string` | Raw query string (if present) |
| `remote_ip` | Client IP (respects `X-Forwarded-For`) |
| `user_agent` | Client user agent string |
| `content_type` | Request content type |
| `http_status` | Response status code |
| `error` | Structured error object (on unhandled errors) |
| `user` | Auto-detected from Warden/Devise (id, email) |

### Via Action Controller subscriber

| Field | Description |
|-------|-------------|
| `controller` | Controller class name |
| `action` | Action name |
| `format` | Response format (html, json, etc.) |
| `params` | Filtered request parameters |
| `view_runtime_ms` | Time spent rendering views |
| `db_runtime_ms` | Time spent in database |

### Via Active Record subscriber

| Field | Description |
|-------|-------------|
| `db_query_count` | Total SQL queries executed |
| `db_total_time_ms` | Cumulative query time |
| `slow_queries` | Array of queries exceeding the threshold |

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

### Error enrichment

Opt-in concern that captures rescued exceptions in controllers:

```ruby
class ApplicationController < ActionController::Base
  include CanonicalLog::Integrations::ErrorEnrichment
end
```

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

## Resources

- [Canonical Log Lines](https://brandur.org/canonical-log-lines) -- The pattern this gem implements
- [Stripe's approach](https://stripe.com/blog/canonical-log-lines) -- Stripe's canonical log lines
- [loggingsucks.com](https://loggingsucks.com/) -- The philosophy behind wide events

## License

MIT
