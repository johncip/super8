require "yaml"
require "csv"

module Super8
  # Represents a recorded cassette stored on disk.
  # Each cassette is a directory containing commands and row data.
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name
      @current_connection_id = nil
      @connections = {}
      @commands = []
      @command_index = 0
    end

    # Full path to the cassette directory.
    def path
      File.join(Super8.config.cassette_directory, name)
    end

    def exists?
      Dir.exist?(path)
    end

    # Generate next connection ID (a, b, c, ..., z, aa, ab, ...)
    def next_connection_id
      return @current_connection_id = "a" if @current_connection_id.nil?
      @current_connection_id = @current_connection_id.succ
    end

    # Writes all cassette data to disk in one pass.
    # Creates directory, row files, and commands.yml.
    def save
      FileUtils.mkdir_p(path)
      process_row_data!
      save_commands_file
    end

    # Loads cassette data for playback.
    # Raises CassetteNotFoundError if missing.
    def load
      raise CassetteNotFoundError, "Cassette not found: #{path}" unless exists?
      @commands = YAML.load_file(
        File.join(path, "commands.yml"),
        permitted_classes: [ODBC::Column]
      )
      @command_index = 0
    end

    # Get next command during playback.
    def next_command
      return nil if @command_index >= @commands.length
      command = @commands[@command_index]
      @command_index += 1
      command
    end

    # Load row data from CSV files.
    def load_rows_from_file(filename)
      CSV.read(File.join(path, filename))
    end

    # Generic recording — stores method name and context in memory.
    def record(method, **context)
      @commands << {"method" => method.to_s, **stringify_keys(context)}
    end

    private

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    # Extracts row data from commands, writes to CSV files, replaces with file references
    def process_row_data!
      @commands.each do |command|
        next unless command.key?("rows_data")

        conn_id = command["connection_id"]
        stmt_id = command["statement_id"]
        method = command["method"]
        file_name = "#{conn_id}_#{stmt_id}_#{method}.csv"
        write_rows_csv_file(file_name, command.delete("rows_data"))
        command["rows_file"] = file_name
      end
    end

    def write_rows_csv_file(file_name, data)
      file_path = File.join(path, file_name)
      CSV.open(file_path, "w") do |csv|
        data.each do |row|
          csv << row.map do |field|
            field&.encode(Super8.config.encoding, invalid: :replace, undef: :replace, replace: "?")
          end
        end
      end
    end

    def save_commands_file
      commands_file = File.join(path, "commands.yml")
      File.write(commands_file, @commands.to_yaml)
    end
  end
end
