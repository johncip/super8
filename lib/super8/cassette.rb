require "yaml"
require "csv"

# :reek:DataClump
# :reek:UncommunicativeModuleName
# :reek:TooManyMethods
module Super8
  # Represents a recorded cassette stored on disk.
  # Each cassette is a directory containing commands and row data.
  class Cassette
    attr_reader :name
    attr_accessor :dsn

    def initialize(name)
      @name = name
      @dsn = nil
      @commands = []
    end

    # Full path to the cassette directory.
    def path
      File.join(Super8.config.cassette_directory, name)
    end

    def exists?
      Dir.exist?(path)
    end

    # Writes all cassette data to disk in one pass.
    # Creates directory, connection.yml, row files, and commands.yml.
    def save
      FileUtils.mkdir_p(path)
      save_connection_file if @dsn
      process_row_data!
      save_commands_file
    end

    # Verifies the cassette exists. Called during playback.
    # Raises CassetteNotFoundError if missing.
    def load
      raise CassetteNotFoundError, "Cassette not found: #{path}" unless exists?
    end

    def load_connection
      YAML.load_file(File.join(path, "connection.yml"))["dsn"]
    end

    # Generic recording — stores method name and context in memory.
    def record(method, **context)
      @commands << {"method" => method.to_s, **stringify_keys(context)}
    end

    private

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    def save_connection_file
      File.write(File.join(path, "connection.yml"), {"dsn" => @dsn}.to_yaml)
    end

    # Extracts row data from commands, writes to CSV files, replaces with file references
    def process_row_data!
      rows_file_counter = 0
      @commands.each do |command|
        next unless command.key?("rows_data")

        file_name = "rows_#{rows_file_counter}.csv"
        rows_file_counter += 1
        write_rows_csv_file(file_name, command.delete("rows_data"))
        command["rows_file"] = file_name
      end
    end

    def write_rows_csv_file(file_name, data)
      file_path = File.join(path, file_name)
      CSV.open(file_path, "w") do |csv|
        data.each { |row| csv << row }
      end
    end

    def save_commands_file
      commands_file = File.join(path, "commands.yml")
      File.write(commands_file, @commands.to_yaml)
    end
  end
end
