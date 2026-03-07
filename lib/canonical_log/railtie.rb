# frozen_string_literal: true

module CanonicalLog
  class Railtie < Rails::Railtie
    config.after_initialize do
      CanonicalLog::RailsLogSuppressor.suppress! if CanonicalLog.configuration.suppress_rails_logging
    end

    initializer 'canonical_log.insert_middleware' do |app|
      app.middleware.insert(0, CanonicalLog::Middleware)
    end

    initializer 'canonical_log.subscribe' do
      CanonicalLog::Subscribers::ActionController.subscribe!
      CanonicalLog::Subscribers::ActiveRecord.subscribe!
      CanonicalLog::Subscribers::ActiveSupportCache.subscribe!
      CanonicalLog::Subscribers::ActiveJob.subscribe! if defined?(ActiveJob)
    end
  end
end
