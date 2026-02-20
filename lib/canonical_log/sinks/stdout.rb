# frozen_string_literal: true

module CanonicalLog
  module Sinks
    class Stdout < Base
      def write(json_string)
        $stdout.puts(json_string)
      end
    end
  end
end
