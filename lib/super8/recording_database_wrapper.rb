module Super8
  # Wraps an ODBC::Database to intercept method calls for recording.
  # Delegates to the real database and logs interactions to the cassette.
  class RecordingDatabaseWrapper
    def initialize(real_db, cassette, connection_id)
      @real_db = real_db
      @cassette = cassette
      @connection_id = connection_id
      @statement_counter = 0
    end

    # Intercept run method to record SQL queries
    def run(sql, *params)
      statement_id = next_statement_id
      @cassette.record(:run, connection_id: @connection_id, sql: sql, params: params, statement_id: statement_id)
      real_statement = @real_db.run(sql, *params)
      RecordingStatementWrapper.new(real_statement, statement_id, @cassette, @connection_id)
    end

    # Delegate all other method calls to the real database for now.
    def method_missing(method_name, ...)
      @real_db.send(method_name, ...)
    end

    # :reek:BooleanParameter
    # :reek:ManualDispatch
    def respond_to_missing?(method_name, include_private=false)
      @real_db.respond_to?(method_name, include_private) || super
    end

    private

    def next_statement_id
      @statement_counter += 1
      @statement_counter
    end
  end
end
