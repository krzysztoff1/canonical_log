# frozen_string_literal: true

require 'json'

module CanonicalLog
  module Formatters
    module Pretty
      CYAN = "\e[36m"
      GREEN = "\e[32m"
      YELLOW = "\e[33m"
      MAGENTA = "\e[35m"
      GRAY = "\e[90m"
      RESET = "\e[0m"

      def self.format(hash)
        json = JSON.pretty_generate(hash)
        colorize(json)
      end

      def self.colorize(json)
        json.gsub(/("(?:[^"\\]|\\.)*")(\s*:)?|(\b(?:true|false)\b)|\bnull\b|(-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)/) do
          if Regexp.last_match(2)
            "#{CYAN}#{Regexp.last_match(1)}#{RESET}#{Regexp.last_match(2)}"
          elsif Regexp.last_match(1)
            "#{GREEN}#{Regexp.last_match(1)}#{RESET}"
          elsif Regexp.last_match(3)
            "#{MAGENTA}#{Regexp.last_match(3)}#{RESET}"
          elsif Regexp.last_match(0) == 'null'
            "#{GRAY}null#{RESET}"
          else
            "#{YELLOW}#{Regexp.last_match(0)}#{RESET}"
          end
        end
      end

      private_class_method :colorize
    end
  end
end
