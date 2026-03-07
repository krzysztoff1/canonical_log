# frozen_string_literal: true

module CanonicalLog
  module Formatters
    module Logfmt
      def self.format(hash)
        flatten(hash).map { |k, v| "#{k}=#{format_value(v)}" }.join(' ')
      end

      def self.flatten(hash, prefix = nil, result = {})
        hash.each do |key, value|
          full_key = prefix ? "#{prefix}.#{key}" : key.to_s
          if value.is_a?(Hash)
            flatten(value, full_key, result)
          else
            result[full_key] = value
          end
        end
        result
      end

      def self.format_value(value)
        case value
        when nil then ''
        when true, false, Numeric then value.to_s
        when Array then maybe_quote(value.join(','))
        else maybe_quote(value.to_s)
        end
      end

      def self.maybe_quote(str)
        if str.empty? || str.match?(/[\s="\\]/)
          "\"#{str.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
        else
          str
        end
      end

      private_class_method :flatten, :format_value, :maybe_quote
    end
  end
end
