# frozen_string_literal: true

require "spec_helper"
require "super8"
require "fakefs/spec_helpers"

RSpec.describe "Playback mode with diff output" do
  include FakeFS::SpecHelpers

  let(:cassette_name) { "test_cassette" }
  let(:cassette_dir) { "/tmp/super8_cassettes" }

  before do
    Super8.configure { |c| c.cassette_directory = cassette_dir }
  end

  describe "SQL query mismatch" do
    it "shows detailed diff for single-line query mismatch" do
      # Create a cassette with a recorded query
      cassette_path = File.join(cassette_dir, cassette_name)
      FileUtils.mkdir_p(cassette_path)

      # Write a commands file with a recorded query
      commands = [
        {
          "connection_id" => 1,
          "method" => "run",
          "sql" => "SELECT * FROM users WHERE id = ?",
          "params" => [123],
          "statement_id" => 1
        }
      ]
      File.write(File.join(cassette_path, "commands.yml"), YAML.dump(commands))

      # Try to replay with a different query
      cassette_loaded = Super8::Cassette.new(cassette_name)
      cassette_loaded.load

      wrapper = Super8::PlaybackDatabaseWrapper.new(cassette_loaded, 1)

      expect {
        wrapper.run("SELECT * FROM customers WHERE id = ?", 123)
      }.to raise_error(Super8::CommandMismatchError) do |error|
        expect(error.message).to include("sql mismatch:")
        expect(error.message).to include("- SELECT * FROM users WHERE id = ?")
        expect(error.message).to include("+ SELECT * FROM customers WHERE id = ?")
      end
    end

    it "shows detailed diff for multi-line query mismatch" do
      # Create a cassette with a multi-line recorded query
      cassette_path = File.join(cassette_dir, cassette_name)
      FileUtils.mkdir_p(cassette_path)

      expected_sql = <<~SQL
        SELECT id, name, email
        FROM users
        WHERE status = 'active'
        ORDER BY created_at DESC
      SQL

      actual_sql = <<~SQL
        SELECT id, username, email
        FROM customers
        WHERE status = 'active'
        ORDER BY created_at ASC
      SQL

      commands = [
        {
          "connection_id" => 1,
          "method" => "run",
          "sql" => expected_sql,
          "params" => [],
          "statement_id" => 1
        }
      ]
      File.write(File.join(cassette_path, "commands.yml"), YAML.dump(commands))

      # Try to replay with a different query
      cassette_loaded = Super8::Cassette.new(cassette_name)
      cassette_loaded.load

      wrapper = Super8::PlaybackDatabaseWrapper.new(cassette_loaded, 1)

      expect {
        wrapper.run(actual_sql)
      }.to raise_error(Super8::CommandMismatchError) do |error|
        expect(error.message).to include("sql mismatch:")
        expect(error.message).to include("- SELECT id, name, email")
        expect(error.message).to include("+ SELECT id, username, email")
        expect(error.message).to include("- FROM users")
        expect(error.message).to include("+ FROM customers")
        expect(error.message).to include("WHERE status = 'active'")
      end
    end

    it "shows regular output for non-SQL mismatches" do
      # Create a cassette with a recorded query
      cassette_path = File.join(cassette_dir, cassette_name)
      FileUtils.mkdir_p(cassette_path)

      commands = [
        {
          "connection_id" => 1,
          "method" => "run",
          "sql" => "SELECT * FROM users",
          "params" => [123],
          "statement_id" => 1
        }
      ]
      File.write(File.join(cassette_path, "commands.yml"), YAML.dump(commands))

      # Try to replay with different params
      cassette_loaded = Super8::Cassette.new(cassette_name)
      cassette_loaded.load

      wrapper = Super8::PlaybackDatabaseWrapper.new(cassette_loaded, 1)

      expect {
        wrapper.run("SELECT * FROM users", 456)
      }.to raise_error(Super8::CommandMismatchError) do |error|
        expect(error.message).to eq("params: expected [123], got [456]")
      end
    end
  end
end
