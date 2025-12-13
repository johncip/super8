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
        # TODO: Need to either support multiple connect calls or fail when detected
        # TODO: Handle storing username when user calls ODBC.connect(dsn, user, password)
        cassette.dsn = dsn

        original_connect.call(dsn) do |db|
          wrapped_db = RecordingDatabaseWrapper.new(db, cassette)
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
        # DSN validation
        recorded_dsn = cassette.load_connection["dsn"]
        unless dsn == recorded_dsn
          raise CommandMismatchError, "dsn: expected '#{recorded_dsn}', got '#{dsn}'"
        end

        # Return fake database object
        playback_db = PlaybackDatabaseWrapper.new(cassette)
        block&.call(playback_db)
      end
    end

    def cleanup_odbc_intercept
      ODBC.define_singleton_method(:connect, @original_connect) if @original_connect
      @original_connect = nil
    end
  end
end
