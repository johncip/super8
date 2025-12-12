module Super8
  # Wraps an ODBC::Statement to intercept method calls for recording.
  # During record mode, delegates to the real statement and logs interactions.
  class RecordingStatementWrapper
    def initialize(real_statement, statement_id, cassette)
      @real_statement = real_statement
      @statement_id = statement_id
      @cassette = cassette
    end

    # Intercept columns method to record column metadata
    # :reek:BooleanParameter
    def columns(as_ary=false) # rubocop:disable Style/OptionalBooleanParameter
      result = @real_statement.columns(as_ary)
      @cassette.record_columns(@statement_id, as_ary, result)
      result
    end

    # Intercept fetch_all method to record row data
    def fetch_all
      result = @real_statement.fetch_all
      @cassette.record_fetch_all(@statement_id, result)
      result
    end

    # Intercept drop method to record cleanup call
    def drop
      result = @real_statement.drop
      @cassette.record_drop(@statement_id)
      result
    end

    # Intercept cancel method to record statement cancellation
    def cancel
      result = @real_statement.cancel
      @cassette.record_cancel(@statement_id)
      result
    end

    # Intercept close method to record statement closure
    def close
      result = @real_statement.close
      @cassette.record_close(@statement_id)
      result
    end

    # Delegate all other method calls to the real statement for now.
    # Future phases will intercept specific methods (fetch, etc.)
    def method_missing(method_name, ...)
      @real_statement.send(method_name, ...)
    end

    # :reek:BooleanParameter
    # :reek:ManualDispatch
    def respond_to_missing?(method_name, include_private=false)
      @real_statement.respond_to?(method_name, include_private) || super
    end
  end
end
