# frozen_string_literal: true

module CanonicalLog
  class Railtie < Rails::Railtie
    initializer 'canonical_log.insert_middleware' do |app|
      app.middleware.insert(0, CanonicalLog::Middleware)
    end

    initializer 'canonical_log.subscribe' do
      CanonicalLog::Subscribers::ActionController.subscribe!
      CanonicalLog::Subscribers::ActiveRecord.subscribe!
    end
  end
end
