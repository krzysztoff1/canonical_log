# frozen_string_literal: true

module CanonicalLog
  module Sinks
    class RailsLogger < Base
      def write(json_string, level: :info)
        Rails.logger.public_send(level, json_string)
      end
    end
  end
end
