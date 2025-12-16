module Super8
  # Wraps ODBC Statement calls during playback mode.
  # Validates that statement interactions match recorded commands and returns recorded data.
  class PlaybackStatementWrapper
    def initialize(statement_id, cassette, connection_id)
      @statement_id = statement_id
      @cassette = cassette
      @connection_id = connection_id
    end

    def fetch_all
      expected_command = @cassette.next_command
      validate_statement_command(expected_command, :fetch_all)

      rows_file_path = expected_command["rows_file"]
      rows_file_path ? @cassette.load_rows_from_file(rows_file_path) : []
    end

    def columns
      expected_command = @cassette.next_command
      validate_statement_command(expected_command, :columns)
      expected_command["result"]
    end

    def drop
      expected_command = @cassette.next_command
      validate_statement_command(expected_command, :drop)
      # drop doesn't return anything
    end

    def close
      expected_command = @cassette.next_command
      validate_statement_command(expected_command, :close)
      # close doesn't return anything
    end

    def cancel
      expected_command = @cassette.next_command
      validate_statement_command(expected_command, :cancel)
      # cancel doesn't return anything
    end

    # Delegate other methods - raise error for unexpected calls
    def method_missing(method_name, ...)
      raise NoMethodError, "Method #{method_name} not implemented for playback"
    end

    def respond_to_missing?(_method_name, _include_private=false)
      false
    end

    private

    def validate_statement_command(expected_command, method)
      validate_command_match(expected_command, method,
                             connection_id: @connection_id, statement_id: @statement_id)
    end

    # :reek:FeatureEnvy
    # :reek:NilCheck
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
