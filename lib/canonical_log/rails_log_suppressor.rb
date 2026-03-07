# frozen_string_literal: true

module CanonicalLog
  module RailsLogSuppressor
    def self.suppress!
      ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
        next unless ['ActionController::LogSubscriber', 'ActionView::LogSubscriber']
          .include?(subscriber.class.name)

        subscriber.logger = Logger.new(File::NULL)
      end
    end
  end
end
