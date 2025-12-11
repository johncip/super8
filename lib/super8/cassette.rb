require "yaml"
require "csv"

# :reek:UncommunicativeModuleName
module Super8
  # Represents a recorded cassette stored on disk.
  # Each cassette is a directory containing commands and row data.
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name
      @commands = []
      @statement_counter = 0
      @rows_file_counter = 0
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
    def record_run(sql, params=[])
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

    # Records a Statement#columns command to the command log
    def record_columns(statement_id, as_ary, result)
      command = {
        "method" => "columns",
        "statement_id" => statement_id,
        "as_aray" => as_ary,
        "result" => result
      }

      @commands << command
      save_commands
    end

    # Records a Statement#fetch_all command and saves row data to file
    #
    # :reek:ControlParameter
    def record_fetch_all(statement_id, result)
      # Normalize nil to empty array to match CSV playback behavior
      normalized_result = result || []
      record_rows_data(statement_id, "fetch_all", normalized_result, :csv)
    end

    private

    # Generic method to record row data in different formats
    #
    # :reek:LongParameterList
    # :reek:TooManyStatements
    def record_rows_data(statement_id, method_name, data, format)
      extension = format == :csv ? "csv" : "yml"
      file_name = "rows_#{@rows_file_counter}.#{extension}"
      @rows_file_counter += 1

      # Write data file in specified format
      case format
      when :csv
        write_rows_csv_file(file_name, data)
      when :yaml
        write_rows_yaml_file(file_name, data)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      # Add command to log
      command = {
        "method" => method_name,
        "statement_id" => statement_id,
        "rows_file" => file_name
      }
      @commands << command
      save_commands
    end

    def write_rows_csv_file(file_name, data)
      file_path = File.join(path, file_name)
      CSV.open(file_path, "w") do |csv|
        data.each { |row| csv << row }
      end
    end

    def write_rows_yaml_file(file_name, data)
      file_path = File.join(path, file_name)
      File.write(file_path, data.to_yaml)
    end

    def save_commands
      commands_file = File.join(path, "commands.yml")
      File.write(commands_file, @commands.to_yaml)
    end
  end
end
