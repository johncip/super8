module Super8
  # Wraps an ODBC::Statement to intercept method calls for recording.
  # During record mode, delegates to the real statement and logs interactions.
  # During playback mode, returns recorded responses without calling real methods.
  class StatementWrapper
    def initialize(real_statement, statement_id, cassette)
      @real_statement = real_statement
      @statement_id = statement_id
      @cassette = cassette
    end

    # Delegate all method calls to the real statement for now.
    # Future phases will intercept specific methods (columns, fetch_all, etc.)
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
