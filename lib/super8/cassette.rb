require "yaml"

module Super8
  # Represents a recorded cassette stored on disk.
  # Each cassette is a directory containing commands and row data.
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name
      @commands = []
      @statement_counter = 0
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

    def save_connection(dsn)
      File.write(File.join(path, "connection.yml"), {"dsn" => dsn}.to_yaml)
    end

    def load_connection
      YAML.load_file(File.join(path, "connection.yml"))["dsn"]
    end

    # Records a Database#run command to the command log
    def record_run(sql, params = [])
      statement_id = "stmt_#{@statement_counter}"
      @statement_counter += 1
      
      command = {
        "method" => "run",
        "sql" => sql,
        "params" => params,
        "statement_id" => statement_id
      }
      
      @commands << command
      save_commands
      statement_id
    end

    private

    def save_commands
      commands_file = File.join(path, "commands.yml")
      File.write(commands_file, @commands.to_yaml)
    end
  end
end
