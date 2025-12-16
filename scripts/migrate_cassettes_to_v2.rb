#!/usr/bin/env ruby
# Script to convert old cassettes to ADR 005 format
# - Adds connect command with connection_id
# - Converts stmt_N to integer IDs
# - Renames rows_N.csv to a_N_<method>.csv
# - Adds connection_id to all commands

require "yaml"
require "fileutils"
require "odbc"

def convert_cassette(cassette_path)
  puts "Converting cassette: #{cassette_path}"
  
  # Load connection.yml
  connection_file = File.join(cassette_path, "connection.yml")
  unless File.exist?(connection_file)
    puts "  No connection.yml found, skipping"
    return
  end
  
  connection_data = YAML.load_file(connection_file)
  dsn = connection_data["dsn"]
  
  # Load commands.yml
  commands_file = File.join(cassette_path, "commands.yml")
  commands = YAML.load_file(commands_file, permitted_classes: [ODBC::Column])
  
  # Create connect command
  connect_command = {
    "method" => "connect",
    "connection_id" => "a",
    "dsn" => dsn
  }
  
  # Convert existing commands
  converted_commands = [connect_command]
  
  commands.each do |cmd|
    # Add connection_id to all commands
    cmd["connection_id"] = "a"
    
    # Convert statement_id from stmt_N to integer
    if cmd["statement_id"]
      stmt_num = cmd["statement_id"].sub("stmt_", "").to_i + 1
      cmd["statement_id"] = stmt_num
    end
    
    # Rename rows_file references
    if cmd["rows_file"]
      old_file = cmd["rows_file"]
      method = cmd["method"]
      stmt_id = cmd["statement_id"]
      new_file = "a_#{stmt_id}_#{method}.csv"
      cmd["rows_file"] = new_file
      
      # Rename actual file
      old_path = File.join(cassette_path, old_file)
      new_path = File.join(cassette_path, new_file)
      if File.exist?(old_path)
        FileUtils.mv(old_path, new_path)
        puts "  Renamed: #{old_file} -> #{new_file}"
      end
    end
    
    converted_commands << cmd
  end
  
  # Write updated commands.yml
  File.write(commands_file, converted_commands.to_yaml)
  puts "  Updated commands.yml"
  
  # Delete connection.yml
  FileUtils.rm(connection_file)
  puts "  Deleted connection.yml"
  
  puts "  ✓ Conversion complete"
end

# Main script
if ARGV.empty?
  puts "Usage: #{$0} <cassettes_directory>"
  puts "Example: #{$0} spec/super8_cassettes"
  exit 1
end

cassettes_dir = ARGV[0]

unless Dir.exist?(cassettes_dir)
  puts "Directory not found: #{cassettes_dir}"
  exit 1
end

# Find all cassette subdirectories (ones with commands.yml)
cassette_paths = Dir.glob(File.join(cassettes_dir, "*")).select do |path|
  Dir.exist?(path) && File.exist?(File.join(path, "commands.yml"))
end

if cassette_paths.empty?
  puts "No cassettes found in #{cassettes_dir}"
  exit 0
end

puts "Found #{cassette_paths.length} cassette(s) to convert\n\n"

cassette_paths.each do |cassette_path|
  convert_cassette(cassette_path)
  puts
end

puts "All conversions complete!"
