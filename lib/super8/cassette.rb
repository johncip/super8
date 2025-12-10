module Super8
  # Represents a recorded cassette stored on disk.
  # Each cassette is a directory containing commands and row data.
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name
    end

    # Full path to the cassette directory.
    def path
      File.join(Super8.config.cassette_directory, name)
    end

    def exists?
      Dir.exist?(path)
    end

    # Creates the cassette directory. Called during recording.
    def save
      FileUtils.mkdir_p(path)
    end

    # Verifies the cassette exists. Called during playback.
    # Raises CassetteNotFoundError if missing.
    def load
      raise CassetteNotFoundError, "Cassette not found: #{path}" unless exists?
    end
  end
end
