# frozen_string_literal: true

# Demo script to show diff output examples
require_relative "../lib/super8"

puts "=" * 80
puts "Super8 Diff Output Examples"
puts "=" * 80

# Example 1: Single-line query difference
puts "\n1. Single-line SQL query mismatch:"
puts "-" * 80
expected = "SELECT * FROM users WHERE id = ?"
actual = "SELECT * FROM customers WHERE id = ?"
puts Super8::DiffHelper.generate_diff(expected, actual, key: "sql")

# Example 2: Multi-line query difference
puts "\n\n2. Multi-line SQL query mismatch:"
puts "-" * 80
expected_multi = <<~SQL
  SELECT id, name, email
  FROM users
  WHERE status = 'active'
  ORDER BY created_at DESC
SQL

actual_multi = <<~SQL
  SELECT id, username, email
  FROM customers
  WHERE status = 'active'
  ORDER BY created_at ASC
SQL

puts Super8::DiffHelper.generate_diff(expected_multi, actual_multi, key: "sql")

# Example 3: Different number of lines
puts "\n\n3. Query with added line:"
puts "-" * 80
expected_short = <<~SQL
  SELECT * FROM users
  WHERE active = true
SQL

actual_long = <<~SQL
  SELECT * FROM users
  WHERE active = true
  AND deleted_at IS NULL
SQL

puts Super8::DiffHelper.generate_diff(expected_short, actual_long, key: "sql")

# Example 4: Non-string values (fallback to inspect)
puts "\n\n4. Non-SQL mismatch (uses regular inspect):"
puts "-" * 80
puts Super8::DiffHelper.generate_diff([123], [456], key: "params")

puts "\n" + "=" * 80
