# frozen_string_literal: true

module CanonicalLog
  module Sinks
    class RailsLogger < Base
      def write(json_string)
        Rails.logger.info(json_string)
      end
    end
  end
end
