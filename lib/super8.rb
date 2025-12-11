require_relative "super8/config"
require_relative "super8/errors"
require_relative "super8/cassette"
require_relative "super8/statement_wrapper"
require "odbc"

module Super8
  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end

    # Wraps a block with cassette recording/playback.
    # In record mode, ODBC calls are captured and saved.
    # In playback mode, recorded responses are returned.
    def use_cassette(name)
      cassette = Cassette.new(name)
      original_connect = ODBC.method(:connect)
      
      ODBC.define_singleton_method(:connect) do |dsn, &block|
        # TODO: Handle storing username when user calls ODBC.connect(dsn, user, password)
        cassette.save
        cassette.save_connection(dsn)
        
        original_connect.call(dsn) do |db|
          # Intercept Database#run to record SQL queries
          original_run = db.method(:run)
          
          db.define_singleton_method(:run) do |sql, *params|
            statement_id = cassette.record_run(sql, params)
            real_statement = original_run.call(sql, *params)
            StatementWrapper.new(real_statement, statement_id, cassette)
          end
          
          block&.call(db)
        end
      end
      
      yield
    ensure
      ODBC.define_singleton_method(:connect, original_connect) if original_connect
    end
  end
end
