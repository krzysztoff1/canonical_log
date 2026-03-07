# frozen_string_literal: true

module CanonicalLog
  module SqlSanitizer
    # Matches single-quoted string literals (including escaped quotes)
    STRING_LITERAL = /'(?:[^'\\]|\\.)*'/

    # Matches numeric literals in value positions (after =, >, <, IN (, comma, etc.)
    NUMERIC_LITERAL = /(?<=[\s=><,(])-?\b\d+(?:\.\d+)?\b/

    def self.sanitize(sql)
      return sql unless sql.is_a?(String)

      result = sql.gsub(STRING_LITERAL, "'?'")
      result.gsub(NUMERIC_LITERAL, '?')
    end
  end
end
