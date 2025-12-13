#!/usr/bin/env ruby
# Investigation script for ruby-odbc prepared statements and parameterized queries
#
# Purpose: Understand how ruby-odbc handles parameterized queries so we can
#          decide how Super8 should record and match them.
#
# BACKGROUND:
#
# Users can write equivalent queries in different ways:
#
#   # Style A: Parameterized
#   db.run("SELECT * FROM t WHERE x = ?", "value")
#
#   # Style B: Interpolated literal
#   db.run("SELECT * FROM t WHERE x = 'value'")
#
# Both return the same data. If a user refactors from one style to the other,
# should Super8 treat that as:
#   - A match (same effective query)?
#   - A warning (semantically equivalent but structurally different)?
#   - A failure (query changed)?
#
# To make that decision, we need to understand:
#
# 1. What does ruby-odbc do with parameters?
#    - Does it interpolate them into the SQL string before sending?
#    - Or does it send them separately (true prepared statement)?
#    - This affects whether we COULD normalize for comparison.
#
# 2. What information is available to us when intercepting?
#    - Can we see the template SQL?
#    - Can we see the bound parameter values?
#    - Can we reconstruct a "final" SQL string if needed?
#
# 3. After execution, can we tell how the query was made?
#    - Does stmt.nparams reflect what was used?
#    - Is there any way to retrieve the original SQL or bound values?
#
# Run with: bundle exec ruby lib/super8/scripts/investigate_prepared_statements.rb

require_relative "../../../config/environment"
require "odbc"
require "pp"

puts "=== Ruby-ODBC Prepared Statements Investigation ==="
puts

# Use a simple query with a parameter
base_query = <<~SQL.strip
  SELECT FFDDIVN, FFDCUSN, FFDCNMB, FFDSLNB, FFDCMPN
  FROM FFDCSTBP
  WHERE FFDCMPN = ?
  LIMIT 1
SQL

param_value = "  1"

puts "1. WHAT DO WE SEE WHEN INTERCEPTING db.run()?"
puts "-" * 60
puts
puts "If we monkey-patch db.run(), what arguments do we receive?"
puts

begin
  ODBC.connect("retalix") do |db|
    puts "1a. db.run(sql) - no parameters"

    direct_query = <<~SQL
      SELECT FFDDIVN, FFDCUSN, FFDCNMB, FFDSLNB, FFDCMPN
      FROM FFDCSTBP
      WHERE FFDCMPN = '  1'
      LIMIT 1
    SQL

    puts "    Intercepted args would be:"
    puts "      sql: #{direct_query.inspect[0..60]}..."
    puts "      *args: []"

    stmt = db.run(direct_query)
    puts "    Result: nparams=#{stmt.nparams}, ncols=#{stmt.ncols}"
    stmt.drop
    puts

    puts "1b. db.run(sql, *args) - with parameters"
    puts "    Intercepted args would be:"
    puts "      sql: #{base_query.inspect}"
    puts "      *args: #{[param_value].inspect}"

    stmt = db.run(base_query, param_value)
    puts "    Result: nparams=#{stmt.nparams}, ncols=#{stmt.ncols}"
    stmt.drop
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "2. WHAT DOES stmt.nparams TELL US?"
puts "-" * 60
puts
puts "After execution, does nparams reflect what was used?"
puts

begin
  ODBC.connect("retalix") do |db|
    puts "2a. Query executed with literal value (no ? placeholders)"
    direct_query = "SELECT * FROM FFDCSTBP WHERE FFDCMPN = '  1' LIMIT 1"
    stmt = db.run(direct_query)
    puts "    nparams after execution: #{stmt.nparams}"
    stmt.drop

    puts "2b. Query executed with parameter placeholder"
    stmt = db.run(base_query, param_value)
    puts "    nparams after execution: #{stmt.nparams}"
    stmt.drop

    puts "2c. Prepared but not yet executed"
    stmt = db.prepare(base_query)
    puts "    nparams after prepare, before execute: #{stmt.nparams}"
    stmt.drop
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "3. CAN WE RETRIEVE THE SQL OR BOUND VALUES FROM A STATEMENT?"
puts "-" * 60
puts
puts "After a statement is prepared/executed, can we ask it what SQL"
puts "was used, or what parameter values were bound?"
puts

begin
  ODBC.connect("retalix") do |db|
    stmt = db.prepare(base_query)

    puts "Statement methods that might expose SQL or values:"
    stmt_methods = (stmt.methods - Object.methods).sort
    relevant = stmt_methods.select { |m| m.to_s =~ /sql|query|text|param|bind|arg|value/i }
    puts "  #{relevant.join(', ')}"
    puts
    puts "  (If empty, there's no obvious way to retrieve SQL from statement)"
    puts

    puts "Trying methods that might return SQL:"
    %i[to_s inspect].each do |m|
      result = stmt.send(m)
      puts "  stmt.#{m}: #{result.inspect[0..80]}"
    end
    puts

    stmt.execute(param_value)

    puts "After execute, checking Parameter object for bound value:"
    if stmt.nparams > 0
      param = stmt.parameter(0)
      param_methods = (param.methods - Object.methods).sort
      puts "  Parameter methods: #{param_methods.join(', ')}"

      # Try anything that might give us the bound value
      %i[value output_value].each do |m|
        if param.respond_to?(m)
          puts "  param.#{m}: #{param.send(m).inspect}"
        end
      end
    end

    stmt.drop
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "4. DOES RUBY-ODBC INTERPOLATE OR USE TRUE PREPARED STATEMENTS?"
puts "-" * 60
puts
puts "If we prepare once and execute twice with different params,"
puts "does it work? If yes, ruby-odbc maintains template/params separately."
puts

begin
  ODBC.connect("retalix") do |db|
    stmt = db.prepare(base_query)

    puts "Execute #1 with param '  1':"
    stmt.execute("  1")
    r1 = stmt.fetch_all
    puts "  Rows: #{r1.length}"
    stmt.close

    puts "Execute #2 with param '  2' (same prepared statement):"
    stmt.execute("  2")
    r2 = stmt.fetch_all
    puts "  Rows: #{r2.length}"

    stmt.drop
    puts
    if r1.length != r2.length || r1 != r2
      puts "Different results → ruby-odbc keeps template and params separate"
    else
      puts "Same results (might just be same data for both params)"
    end
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "5. DOES QUOTING/ESCAPING DIFFER BETWEEN STYLES?"
puts "-" * 60
puts
puts "If a param value contains special characters, does ruby-odbc"
puts "handle escaping differently than manual string interpolation?"
puts

begin
  ODBC.connect("retalix") do |db|
    # Try a value that might need escaping
    tricky_value = "test'value"

    puts "Testing with value containing a quote: #{tricky_value.inspect}"
    puts

    # This might fail if the table doesn't have such data, but we can
    # at least see if the query executes without SQL injection issues
    test_query = <<~SQL.strip
      SELECT FFDDIVN FROM FFDCSTBP WHERE FFDCNMB = ? LIMIT 1
    SQL

    begin
      stmt = db.run(test_query, tricky_value)
      puts "  Parameterized query executed OK (value was properly escaped)"
      stmt.drop
    rescue StandardError => e
      puts "  Parameterized query error: #{e.message}"
    end
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "6. WHAT ABOUT db.do() WITH PARAMETERS?"
puts "-" * 60
puts
puts "db.do() returns row count and auto-drops. Does it also accept params?"
puts

begin
  ODBC.connect("retalix") do |db|
    puts "6a. db.do(sql) - no parameters"
    direct_query = "SELECT * FROM FFDCSTBP WHERE FFDCMPN = '  1' LIMIT 1"
    result = db.do(direct_query)
    puts "    Return value: #{result.inspect} (class: #{result.class})"
    puts

    puts "6b. db.do(sql, *args) - with parameters"
    result = db.do(base_query, param_value)
    puts "    Return value: #{result.inspect} (class: #{result.class})"
    puts
  end
rescue StandardError => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts
puts "=" * 60
puts "SUMMARY OF FINDINGS"
puts "=" * 60
puts
puts "Review the output above to determine:"
puts
puts "1. At intercept time (db.run, db.prepare, stmt.execute):"
puts "   - Do we receive the SQL template and params separately? [check section 1]"
puts
puts "2. After execution:"
puts "   - Can we retrieve the SQL from the statement? [check section 3]"
puts "   - Can we retrieve bound parameter values? [check section 3]"
puts "   - Does nparams tell us if params were used? [check section 2]"
puts
puts "3. For matching strategy:"
puts "   - If we can only capture at intercept time, we must wrap the methods"
puts "   - If nparams reliably indicates parameterization, we can use it for matching"
puts "   - If we can reconstruct final SQL, we could normalize for comparison"
puts
puts "=== Investigation Complete ==="
