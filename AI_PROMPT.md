# AI Prompt: Add Canonical Logging to a Rails App

Copy the prompt below and paste it into your AI coding assistant (Claude, Cursor, Copilot, etc.) to add structured canonical logging to your Rails application.

---

## The Prompt

```
Add structured canonical logging to this Rails application using the `canonical_log` gem.

## What canonical logging is

One structured JSON log line per request instead of scattered log statements.
Every request produces a single wide event containing all relevant context:
timing, controller, params, DB queries, user info, errors, and business logic fields.

## Step 1: Install the gem

Add to Gemfile:

gem "canonical_log"

Run:

bundle install
rails generate canonical_log:install

This creates `config/initializers/canonical_log.rb`.

## Step 2: Configure the initializer

Update `config/initializers/canonical_log.rb`:

CanonicalLog.configure do |config|
  # Filter sensitive params
  config.param_filter_keys = %w[password password_confirmation token secret api_key access_token]

  # Capture slow queries individually (queries above this threshold in ms)
  config.slow_query_threshold_ms = 100.0

  # Skip noisy paths
  config.ignored_paths = ["/health", "/assets", %r{\A/packs}]

  # Extract user context from Warden/Devise automatically.
  # For custom user context, uncomment and adapt:
  # config.user_context = ->(env) {
  #   user = env['warden']&.user
  #   if user
  #     { id: user.id, email: user.email, role: user.role }
  #   else
  #     {}
  #   end
  # }

  # Add global fields before each event is emitted
  config.before_emit = ->(event) {
    event.context(:service, version: ENV.fetch("APP_VERSION", "unknown"))
  }
end

## Step 3: Add error enrichment to ApplicationController

In `app/controllers/application_controller.rb`, include the ErrorEnrichment concern
so that rescued exceptions are captured in the canonical log line:

include CanonicalLog::Integrations::ErrorEnrichment

## Step 4: Add business context to key controller actions

In important controller actions, add business-specific context using
the categorized context API. This makes logs queryable by domain concepts.

Use these methods anywhere in controllers, models, services, or jobs:

# Categorized context (groups fields under a key)
CanonicalLog.context(:user, id: current_user.id, tier: current_user.tier)
CanonicalLog.context(:business, endpoint: "create_order", order_id: @order.id)

# Flat fields
CanonicalLog.add(checkout_step: "payment", payment_provider: "stripe")

# Counters
CanonicalLog.increment(:external_api_calls)

# Arrays
CanonicalLog.append(:feature_flags, "new_checkout")

# Structured errors
begin
  process_payment
rescue Stripe::CardError => e
  CanonicalLog.add_error(e, code: "card_declined", retriable: false)
end

Available categories: :user, :business, :infra, :service.
All methods are safe to call even when no event is active (they silently no-op).

## Step 5: Add Sidekiq integration (if using Sidekiq)

In `config/initializers/sidekiq.rb`:

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add CanonicalLog::Integrations::Sidekiq
  end
end

Each job will emit its own canonical log line with job_class, queue, jid, timing, and errors.

## Step 6: Production sampling (optional, for high-traffic apps)

CanonicalLog.configure do |config|
  config.sample_rate = 0.05                # Log 5% of normal traffic
  config.slow_request_threshold_ms = 1000  # Always log slow requests
end

Errors (status >= 500) and slow requests are always logged regardless of sample rate.

## What gets captured automatically (no code needed)

Via Rack middleware:
- timestamp, duration_ms, request_id, http_method, path, query_string
- remote_ip, user_agent, content_type, http_status
- error (structured object on unhandled exceptions)
- user (auto-detected from Warden/Devise)

Via Action Controller subscriber:
- controller, action, format, params (filtered), view_runtime_ms, db_runtime_ms

Via Active Record subscriber:
- db_query_count, db_total_time_ms, slow_queries (array of queries above threshold)

## Example output

A single request produces one JSON line like:

{
  "timestamp": "2026-02-19T14:23:01.123Z",
  "duration_ms": 142.35,
  "request_id": "abc-123-def",
  "http_method": "POST",
  "path": "/orders",
  "http_status": 201,
  "controller": "OrdersController",
  "action": "create",
  "params": { "item_id": "42", "quantity": "2" },
  "db_query_count": 8,
  "db_total_time_ms": 45.67,
  "user": { "id": 7891, "email": "buyer@example.com" },
  "business": { "order_id": 12345, "endpoint": "create_order" }
}

## Guidelines

- Add CanonicalLog.context(:business, ...) calls to the 5-10 most important
  controller actions first (order creation, payments, signups, etc.)
- Do NOT scatter logger.info calls — put everything into the canonical log line instead
- Use :business category for domain-specific fields (order_id, payment_status, etc.)
- Use :user category for user identity and attributes
- Use :infra category for infrastructure metadata (region, pod, deploy SHA)
- Use :service category for application metadata (version, git SHA)
- Use CanonicalLog.add_error(exception) in rescue blocks instead of logging errors separately
- Use CanonicalLog.increment(:counter_name) for counting things like API calls or retries
- Filter all sensitive parameters via config.param_filter_keys
```
