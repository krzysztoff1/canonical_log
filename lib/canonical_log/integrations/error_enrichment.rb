# frozen_string_literal: true

require 'active_support/concern'

module CanonicalLog
  module Integrations
    module ErrorEnrichment
      extend ActiveSupport::Concern

      included do
        around_action :capture_errors_for_canonical_log
      end

      private

      def capture_errors_for_canonical_log
        yield
      rescue StandardError => e
        CanonicalLog.add(
          rescued_error_class: e.class.name,
          rescued_error_message: e.message
        )
        raise
      end
    end
  end
end
