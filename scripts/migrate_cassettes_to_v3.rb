#!/usr/bin/env ruby
# Script to convert v2 cassettes to v3 format
#
# Changes in v3:
# - Adds metadata.yml file containing schema version and creation/migration info

require "yaml"
require "fileutils"
require "odbc"

def convert_cassette(cassette_path)
  puts "Converting cassette: #{cassette_path}"

  # Load commands.yml
  commands_file = File.join(cassette_path, "commands.yml")
  unless File.exist?(commands_file)
    puts "  No commands.yml found, skipping"
    return
  end

  # Check if already v3 or higher (has metadata.yml with schema_version >= 3)
  metadata_file = File.join(cassette_path, "metadata.yml")
  if File.exist?(metadata_file)
    metadata = YAML.load_file(metadata_file)
    schema_version = metadata["schema_version"]
    if schema_version && schema_version >= 3
      puts "  Already v#{schema_version} format, skipping"
      return
    end
  end

  # Create metadata.yml
  metadata = {
    "schema_version" => 3,
    "migrated_with" => "migrate_cassettes_to_v3.rb",
    "recorded_on" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  File.write(metadata_file, metadata.to_yaml)
  puts "  ✓ Created metadata.yml with schema_version: 3"
end

# Main script
if ARGV.empty?
  puts "Usage: #{$PROGRAM_NAME} <cassettes_directory>"
  puts "Example: #{$PROGRAM_NAME} spec/super8_cassettes"
  exit 1
end

cassettes_dir = ARGV[0]

unless Dir.exist?(cassettes_dir)
  puts "Directory not found: #{cassettes_dir}"
  exit 1
end

# Find all cassette subdirectories (ones with commands.yml), searching recursively
cassette_paths = Dir.glob(File.join(cassettes_dir, "**", "*")).select do |path|
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
