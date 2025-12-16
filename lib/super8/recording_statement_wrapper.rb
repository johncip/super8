module Super8
  # Wraps an ODBC::Statement to intercept method calls for recording.
  # During record mode, delegates to the real statement and logs interactions.
  class RecordingStatementWrapper
    def initialize(real_statement, statement_id, cassette, connection_id)
      @real_statement = real_statement
      @statement_id = statement_id
      @cassette = cassette
      @connection_id = connection_id
    end

    # Intercept columns method to record column metadata
    # :reek:BooleanParameter
    def columns(as_ary=false) # rubocop:disable Style/OptionalBooleanParameter
      result = @real_statement.columns(as_ary)
      @cassette.record(:columns,
                       connection_id: @connection_id, statement_id: @statement_id,
                       as_ary: as_ary, result: result)
      result
    end

    # Intercept fetch_all method to record row data
    def fetch_all
      result = @real_statement.fetch_all
      # Normalize nil to empty array to match CSV playback behavior
      normalized_result = result || []
      @cassette.record(:fetch_all,
                       connection_id: @connection_id, statement_id: @statement_id,
                       rows_data: normalized_result)
      result
    end

    # Intercept drop method to record cleanup call
    def drop
      result = @real_statement.drop
      @cassette.record(:drop, connection_id: @connection_id, statement_id: @statement_id)
      result
    end

    # Intercept cancel method to record statement cancellation
    def cancel
      result = @real_statement.cancel
      @cassette.record(:cancel, connection_id: @connection_id, statement_id: @statement_id)
      result
    end

    # Intercept close method to record statement closure
    def close
      result = @real_statement.close
      @cassette.record(:close, connection_id: @connection_id, statement_id: @statement_id)
      result
    end

    # Delegate all other method calls to the real statement for now.
    # Future phases will intercept specific methods (fetch, etc.)
    def method_missing(method_name, ...)
      @real_statement.send(method_name, ...)
    end

    def respond_to_missing?(method_name, include_private=false)
      @real_statement.respond_to?(method_name, include_private) || super
    end
  end
end
