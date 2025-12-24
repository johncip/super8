# frozen_string_literal: true

require "diff/lcs"

module Super8
  # Helper module for generating diffs in error messages.
  module DiffHelper
    # Generate a diff between expected and actual values.
    def self.generate_diff(expected, actual, key: "value")
      # Handle nil cases
      return "#{key}: expected #{expected.inspect}, got #{actual.inspect}" if expected.nil? || actual.nil?

      # For non-string values, fall back to inspect
      return "#{key}: expected #{expected.inspect}, got #{actual.inspect}" unless expected.is_a?(String) && actual.is_a?(String)

      expected_lines = expected.lines.map(&:chomp)
      actual_lines = actual.lines.map(&:chomp)

      diff = Diff::LCS.sdiff(expected_lines, actual_lines)
      
      result = ["#{key} mismatch:"]
      diff.each_with_index do |change, i|
        case change.action
        when "-"
          result << "  - #{change.old_element}"
        when "+"
          result << "  + #{change.new_element}"
        when "!"
          result << "  - #{change.old_element}"
          result << "  + #{change.new_element}"
        when "="
          result << "    #{change.old_element}"
        end
      end
      
      result.join("\n")
    end
  end
end
