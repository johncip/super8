require_relative "diff_helper"

module Super8
  # Wraps ODBC calls during playback mode.
  # Validates that interactions match recorded commands and returns recorded data.
  class PlaybackDatabaseWrapper
    def initialize(cassette, connection_id)
      @cassette = cassette
      @connection_id = connection_id
    end

    def run(sql, *params)
      expected_command = @cassette.next_command
      validate_command_match(expected_command, :run,
                             connection_id: @connection_id, sql: sql, params: params)

      statement_id = expected_command["statement_id"]
      PlaybackStatementWrapper.new(statement_id, @cassette, @connection_id)
    end

    # Delegate other methods - they shouldn't be called in typical playback scenarios
    def method_missing(method_name, ...)
      raise NoMethodError, "Method #{method_name} not implemented for playback"
    end

    def respond_to_missing?(_method_name, _include_private=false)
      false
    end

    private

    def validate_command_match(expected_command, method, **actual_context)
      raise CommandMismatchError, "No more recorded interactions" if expected_command.nil?

      # Check method
      if expected_command["method"] != method.to_s
        raise CommandMismatchError,
              "method: expected '#{expected_command['method']}', got '#{method}'"
      end

      # Check each key/value pair
      actual_context.each do |key, value|
        expected_value = expected_command[key.to_s]
        next if expected_value == value

        # Use diff for SQL queries to show detailed differences
        error_message = if key == :sql && expected_value.is_a?(String) && value.is_a?(String)
                          DiffHelper.generate_diff(expected_value, value, key: "sql")
                        else
                          "#{key}: expected #{expected_value.inspect}, got #{value.inspect}"
                        end

        raise CommandMismatchError, error_message
      end
    end
  end
end
