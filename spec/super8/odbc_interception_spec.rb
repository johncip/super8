require "spec_helper"
require "fakefs/spec_helpers"

RSpec.describe "ODBC interception" do # rubocop:disable RSpec/DescribeClass
  include FakeFS::SpecHelpers

  let(:cassette_name) { "test_cassette" }
  let(:cassette_dir) { Super8.config.cassette_directory }
  let(:cassette_path) { File.join(cassette_dir, cassette_name) }
  let(:fake_db) { instance_double(ODBC::Database) }
  let(:fake_statement) { instance_double(ODBC::Statement) }

  # Store original method to test restoration
  let(:original_connect) { ODBC.method(:connect) }

  before do
    allow(fake_db).to receive(:run)
    allow(ODBC).to receive(:connect) do |_dsn, &block|
      block&.call(fake_db)
    end
  end

  describe "ODBC.connect" do
    it "saves DSN to connection.yml" do
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") {} # rubocop:disable Lint/EmptyBlock
      end

      connection_file = File.join(cassette_path, "connection.yml")
      connection_data = YAML.load_file(connection_file)
      expect(connection_data["dsn"]).to eq("retalix")
    end

    it "restores original ODBC.connect after use_cassette block" do # rubocop:disable RSpec/ExampleLength
      method_during_block = nil

      Super8.use_cassette(cassette_name) do
        method_during_block = ODBC.method(:connect)
        ODBC.connect("retalix") {} # rubocop:disable Lint/EmptyBlock
      end

      # The method should have been replaced during the block
      expect(method_during_block).not_to eq(original_connect)

      # And restored after
      expect(ODBC.method(:connect)).to eq(original_connect)
    end
  end

  describe "Database#run" do
    it "records SQL queries to commands.yml" do # rubocop:disable RSpec/ExampleLength
      sql = "SELECT ID, NAME FROM USERS WHERE STATUS = 'A'"
      allow(fake_db).to receive(:run).with(sql).and_return(fake_statement)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          db.run(sql)
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      expect(File.exist?(commands_file)).to be true

      commands = YAML.load_file(commands_file)
      expect(commands).to be_an(Array)
      expect(commands.length).to eq(1)

      first_command = commands.first

      aggregate_failures do
        expect(first_command["method"]).to eq("run")
        expect(first_command["sql"]).to eq(sql)
        expect(first_command["params"]).to eq([])
        expect(first_command["statement_id"]).to match(/stmt_\d+/)
      end
    end

    it "records multiple queries with sequential statement IDs" do # rubocop:disable RSpec/ExampleLength
      sql1 = "SELECT * FROM CUSTOMERS"
      sql2 = "SELECT * FROM ORDERS"
      allow(fake_db).to receive(:run).with(sql1).and_return(fake_statement)
      allow(fake_db).to receive(:run).with(sql2).and_return(fake_statement)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          db.run(sql1)
          db.run(sql2)
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      expect(commands.length).to eq(2)
      expect(commands[0]["statement_id"]).to eq("stmt_0")
      expect(commands[1]["statement_id"]).to eq("stmt_1")
    end

    it "records commands in array order" do # rubocop:disable RSpec/ExampleLength
      sql = "SELECT COUNT(*) FROM PRODUCTS"
      allow(fake_db).to receive(:run).with(sql).and_return(fake_statement)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          db.run(sql)
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      expect(commands).to be_an(Array)
      expect(commands.length).to eq(1)
      expect(commands.first["method"]).to eq("run")
    end
  end
end
