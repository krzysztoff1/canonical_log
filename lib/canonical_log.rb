# frozen_string_literal: true

require 'active_support'

require_relative 'canonical_log/version'
require_relative 'canonical_log/configuration'
require_relative 'canonical_log/sampling'
require_relative 'canonical_log/event'
require_relative 'canonical_log/context'
require_relative 'canonical_log/middleware'
require_relative 'canonical_log/sinks/base'
require_relative 'canonical_log/sinks/stdout'
require_relative 'canonical_log/sinks/rails_logger'
require_relative 'canonical_log/subscribers/action_controller'
require_relative 'canonical_log/subscribers/active_record'
require_relative 'canonical_log/integrations/error_enrichment'
require_relative 'canonical_log/integrations/sidekiq' if defined?(Sidekiq)

require_relative 'canonical_log/railtie' if defined?(Rails::Railtie)

module CanonicalLog
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience delegations to current event
    def add(hash)
      Context.current&.add(hash)
    end

    def set(key, value)
      Context.current&.set(key, value)
    end

    def increment(key, by = 1)
      Context.current&.increment(key, by)
    end

    def append(key, value)
      Context.current&.append(key, value)
    end

    # Categorized context: CanonicalLog.context(:user, id: 123)
    def context(category, data)
      Context.current&.context(category, data)
    end

    # Structured error: CanonicalLog.add_error(exception)
    def add_error(error, metadata = {})
      Context.current&.add_error(error, metadata)
    end
  end
end
