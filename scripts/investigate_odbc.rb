#!/usr/bin/env ruby
# Investigation script for ruby-odbc internals
#
# Purpose: Discover implementation details needed for Super 8 (VCR-like library for ODBC)
#
# What this script investigates:
#
# 1. CONNECTION SCOPE INFORMATION
#    - What metadata can we extract from ODBC::Database connection?
#    - DSN name, server hostname, database/catalog name, schema/library
#    - Username (if exposed by driver, despite not being passed to connect())
#    - Driver and DBMS information
#    - Goal: Determine what to record in connection.yml for scope matching
#
# 2. RESPONSE DATA TYPES
#    - Does statement.fetch_all return typed data (Integer, Date, Float)?
#    - Or are all values returned as strings?
#    - Goal: Decide if Marshal is necessary to preserve types
#
# 3. COLUMN METADATA STRUCTURE
#    - What exactly does statement.columns return? (Hash or Array?)
#    - What does statement.columns(true) return?
#    - What properties are available on column objects?
#    - Goal: Determine format for columns_N.yml
#
# 4. MARSHAL COMPATIBILITY
#    - Can response data be marshaled and unmarshaled?
#    - Are types preserved through marshal round-trip?
#    - Goal: Confirm Marshal is safe for response_N.marshal files
#
# 5. STATEMENT LIFECYCLE
#    - What methods are available on ODBC::Statement?
#    - Which methods do we need to intercept/stub?
#    - Goal: Identify complete monkey-patching surface area
#
# Run with: bundle exec ruby lib/super8/scripts/investigate_odbc.rb

require_relative "../../../config/environment"
require "odbc"
require "pp"

puts "=== Ruby-ODBC Investigation ==="
puts

# Test query - simple one to minimize data
query = "SELECT TOP 1 * FROM CUSTOMERS"

puts "1. CONNECTION API & SCOPE"
puts "-" * 50

# The pattern used in RetalixCSVExporter
puts "Current usage: ODBC.connect('retalix')"
puts "This passes only DSN name, no user/password args"
puts "Credentials must be in system ODBC config (/etc/odbc.ini)"
puts

puts "Testing connection..."
begin
  ODBC.connect("retalix") do |db|
    puts "✓ Connection successful"
    puts "Connection class: #{db.class}"
    puts
    
    puts "Connection scope information:"
    puts "-" * 30
    
    # Try to get various scope information
    scope_methods = [
      :get_info,
      :connected?,
      :database,
      :server,
      :dsn,
      :user
    ]
    
    available_methods = db.methods.sort - Object.methods
    puts "Available connection methods (sample):"
    puts available_methods.first(20).join(", ")
    puts "... (#{available_methods.length} total methods)"
    puts
    
    # Try get_info with various ODBC info types
    puts "Attempting to query connection metadata via get_info:"
    info_types = {
      "SQL_DATABASE_NAME" => 16,      # Current database
      "SQL_SERVER_NAME" => 13,        # Server name
      "SQL_DBMS_NAME" => 17,         # DBMS name
      "SQL_DBMS_VER" => 18,          # DBMS version
      "SQL_DATA_SOURCE_NAME" => 2,   # DSN
      "SQL_DRIVER_NAME" => 6,        # Driver name
      "SQL_USER_NAME" => 47          # Username
    }
    
    info_types.each do |name, code|
      begin
        value = db.get_info(code)
        puts "  #{name}: #{value.inspect}"
      rescue => e
        puts "  #{name}: [error: #{e.message}]"
      end
    end
    puts
    
    # Try using constant names if available
    puts "Attempting with ODBC constants (if defined):"
    [
      "SQL_DATABASE_NAME",
      "SQL_SERVER_NAME", 
      "SQL_DATA_SOURCE_NAME",
      "SQL_USER_NAME"
    ].each do |const_name|
      begin
        if ODBC.const_defined?(const_name)
          const_value = ODBC.const_get(const_name)
          value = db.get_info(const_value)
          puts "  #{const_name}: #{value.inspect}"
        else
          puts "  #{const_name}: [constant not defined]"
        end
      rescue => e
        puts "  #{const_name}: [error: #{e.message}]"
      end
    end
    puts
    
    puts "2. QUERY EXECUTION"
    puts "-" * 50
    
    statement = db.run(query)
    puts "Statement class: #{statement.class}"
    puts "Statement methods: #{statement.methods.sort - Object.methods}"
    puts
    
    puts "3. COLUMN METADATA"
    puts "-" * 50
    
    columns = statement.columns
    puts "Columns return value class: #{columns.class}"
    puts "Columns structure:"
    pp columns
    puts
    
    if columns.is_a?(Hash)
      puts "Columns is a Hash with:"
      puts "  Keys (column names): #{columns.keys}"
      puts "  Values: #{columns.values}"
      
      first_col_name, first_col_value = columns.first
      puts "\nFirst column details:"
      puts "  Name: #{first_col_name.inspect}"
      puts "  Value: #{first_col_value.inspect}"
      puts "  Value class: #{first_col_value.class}"
    end
    puts
    
    puts "4. RESPONSE DATA"
    puts "-" * 50
    
    records = statement.fetch_all
    puts "fetch_all return value class: #{records.class}"
    puts "Number of records: #{records.length}"
    
    if records && !records.empty?
      first_record = records.first
      puts "\nFirst record:"
      puts "  Class: #{first_record.class}"
      puts "  Length: #{first_record.length}"
      puts "  Content:"
      pp first_record
      puts
      
      puts "Field type analysis:"
      first_record.each_with_index do |field, idx|
        puts "  Field #{idx}: #{field.class} - #{field.inspect[0..50]}"
      end
      puts
      
      puts "Checking for typed data:"
      first_record.each_with_index do |field, idx|
        case field
        when Integer
          puts "  ✓ Field #{idx} is Integer: #{field}"
        when Float
          puts "  ✓ Field #{idx} is Float: #{field}"
        when Date
          puts "  ✓ Field #{idx} is Date: #{field}"
        when Time
          puts "  ✓ Field #{idx} is Time: #{field}"
        when String
          puts "  Field #{idx} is String: #{field[0..30].inspect}"
        when NilClass
          puts "  Field #{idx} is nil"
        else
          puts "  Field #{idx} is #{field.class}: #{field.inspect[0..30]}"
        end
      end
    end
    puts
    
    puts "5. MARSHAL TEST"
    puts "-" * 50
    
    if records && !records.empty?
      # Test if we can marshal the data
      begin
        marshaled = Marshal.dump(records)
        puts "✓ Records can be marshaled"
        puts "  Marshaled size: #{marshaled.bytesize} bytes"
        
        unmarshaled = Marshal.load(marshaled)
        puts "✓ Records can be unmarshaled"
        puts "  Data preserved: #{records == unmarshaled}"
        
        # Check if types are preserved
        records.first.each_with_index do |field, idx|
          orig_class = field.class
          restored_class = unmarshaled.first[idx].class
          if orig_class != restored_class
            puts "  ⚠ Type changed for field #{idx}: #{orig_class} -> #{restored_class}"
          end
        end
      rescue => e
        puts "✗ Marshal failed: #{e.message}"
      end
    end
    puts
    
    puts "6. COLUMN METADATA via #columns method"
    puts "-" * 50
    
    # Try getting column as array
    begin
      columns_array = statement.columns(true)
      puts "columns(true) returns array: #{columns_array.class}"
      if columns_array.is_a?(Array)
        puts "Array length: #{columns_array.length}"
        puts "First element:"
        pp columns_array.first
        if columns_array.first.respond_to?(:name)
          puts "  Has #name method: #{columns_array.first.name}"
        end
        if columns_array.first.respond_to?(:type)
          puts "  Has #type method: #{columns_array.first.type}"
        end
      end
    rescue => e
      puts "columns(true) error: #{e.message}"
    end
    puts
    
    statement.drop
  end
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts
puts "=== Investigation Complete ==="
