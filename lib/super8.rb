require_relative "super8/version"
require_relative "super8/config"
require_relative "super8/errors"
require_relative "super8/cassette"
require_relative "super8/recording_database_wrapper"
require_relative "super8/recording_statement_wrapper"
require_relative "super8/playback_database_wrapper"
require_relative "super8/playback_statement_wrapper"
require "odbc"

# Top-level module for Super 8.
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
    #
    # :reek:TooManyStatements
    # :reek:NestedIterators
    def use_cassette(name, mode: :record)
      cassette = Cassette.new(name)

      case mode
      when :record
        setup_recording_mode(cassette)
      when :playback
        setup_playback_mode(cassette)
      else
        raise ArgumentError, "Unknown mode: #{mode}. Use :record or :playback"
      end

      yield
    ensure
      cleanup_odbc_intercept
      cassette.save if mode == :record
    end

    private

    # :reek:NestedIterators
    def setup_recording_mode(cassette)
      original_connect = ODBC.method(:connect)
      @original_connect = original_connect

      ODBC.define_singleton_method(:connect) do |dsn, &block|
        # Generate connection ID for this connection
        connection_id = cassette.next_connection_id

        # Record connect command with connection metadata
        cassette.record(:connect, connection_id: connection_id, dsn: dsn)

        original_connect.call(dsn) do |db|
          wrapped_db = RecordingDatabaseWrapper.new(db, cassette, connection_id)
          block&.call(wrapped_db)
        end
      end
    end

    # :reek:TooManyStatements
    def setup_playback_mode(cassette)
      cassette.load # Load cassette data

      original_connect = ODBC.method(:connect)
      @original_connect = original_connect

      ODBC.define_singleton_method(:connect) do |dsn, &block|
        # Get next connect command from cassette
        expected_command = cassette.next_command
        raise CommandMismatchError, "No more recorded interactions" if expected_command.nil?

        # Validate it's a connect command
        unless expected_command["method"] == "connect"
          raise CommandMismatchError,
                "method: expected 'connect', got '#{expected_command['method']}'"
        end

        # Validate DSN matches
        recorded_dsn = expected_command["dsn"]
        unless dsn == recorded_dsn
          raise CommandMismatchError, "dsn: expected '#{recorded_dsn}', got '#{dsn}'"
        end

        # Extract connection ID
        connection_id = expected_command["connection_id"]

        # Return fake database object
        playback_db = PlaybackDatabaseWrapper.new(cassette, connection_id)
        block&.call(playback_db)
      end
    end

    def cleanup_odbc_intercept
      ODBC.define_singleton_method(:connect, @original_connect) if @original_connect
      @original_connect = nil
    end
  end
end
