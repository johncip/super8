require_relative "super8/config"
require_relative "super8/errors"
require_relative "super8/cassette"

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
      # TODO: implement cassette insertion, ODBC interception, ejection
      yield
    end
  end
end
