module Super8
  # Wraps ODBC calls during playback mode.
  # Validates that interactions match recorded commands and returns recorded data.
  class PlaybackDatabaseWrapper
    def initialize(cassette)
      @cassette = cassette
    end

    def run(sql, *params)
      expected_command = @cassette.next_command
      validate_command_match(expected_command, :run, sql: sql, params: params)

      statement_id = expected_command["statement_id"]
      PlaybackStatementWrapper.new(statement_id, @cassette)
    end

    # Delegate other methods - they shouldn't be called in typical playback scenarios
    def method_missing(method_name, ...)
      raise NoMethodError, "Method #{method_name} not implemented for playback"
    end

    # :reek:BooleanParameter
    # :reek:ManualDispatch
    def respond_to_missing?(_method_name, _include_private=false)
      false
    end

    private

    # :reek:NilCheck
    # :reek:FeatureEnvy
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
        if expected_value != value
          raise CommandMismatchError,
                "#{key}: expected #{expected_value.inspect}, got #{value.inspect}"
        end
      end
    end
  end
end
