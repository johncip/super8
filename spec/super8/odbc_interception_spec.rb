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

  describe "Statement#columns" do
    let(:columns_hash) { {"ID" => "Integer", "NAME" => "String"} }
    let(:columns_array) { [{"name" => "ID", "type" => 4}, {"name" => "NAME", "type" => 1}] }

    before do
      allow(fake_db).to receive(:run).and_return(fake_statement)
    end

    it "records columns call with as_ary=false and returns original result" do # rubocop:disable RSpec/ExampleLength
      allow(fake_statement).to receive(:columns).with(false).and_return(columns_hash)

      result = nil
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM USERS")
          result = statement.columns
        end
      end

      expect(result).to eq(columns_hash)

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      columns_command = commands.find { |cmd| cmd["method"] == "columns" }
      expect(columns_command).not_to be_nil

      aggregate_failures do
        expect(columns_command["method"]).to eq("columns")
        expect(columns_command["statement_id"]).to eq("stmt_0")
        expect(columns_command["as_aray"]).to be false
        expect(columns_command["result"]).to eq(columns_hash)
      end
    end

    it "records columns call with as_ary=true and returns original result" do # rubocop:disable RSpec/ExampleLength
      allow(fake_statement).to receive(:columns).with(true).and_return(columns_array)

      result = nil
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM USERS")
          result = statement.columns(true)
        end
      end

      expect(result).to eq(columns_array)

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      columns_command = commands.find { |cmd| cmd["method"] == "columns" }
      expect(columns_command).not_to be_nil

      aggregate_failures do
        expect(columns_command["method"]).to eq("columns")
        expect(columns_command["statement_id"]).to eq("stmt_0")
        expect(columns_command["as_aray"]).to be true
        expect(columns_command["result"]).to eq(columns_array)
      end
    end

    it "records multiple columns calls in sequence" do # rubocop:disable RSpec/ExampleLength
      allow(fake_statement).to receive(:columns).with(false).and_return(columns_hash)
      allow(fake_statement).to receive(:columns).with(true).and_return(columns_array)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM USERS")
          statement.columns
          statement.columns(true)
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      columns_commands = commands.select { |cmd| cmd["method"] == "columns" }

      aggregate_failures do
        expect(columns_commands.length).to eq(2)
        expect(columns_commands[0]["as_aray"]).to be false
        expect(columns_commands[0]["result"]).to eq(columns_hash)
        expect(columns_commands[1]["as_aray"]).to be true
        expect(columns_commands[1]["result"]).to eq(columns_array)
      end
    end
  end

  # TODO: break these specs up meaningfully
  describe "Statement#fetch_all" do
    let(:row_data) { [["001", "Alice"], ["002", "Bob"], ["003", "Charlie"]] }

    it "records fetch_all call and saves row data to CSV file" do # rubocop:disable RSpec/ExampleLength
      allow(fake_db).to receive(:run).with("SELECT id, name FROM users").and_return(fake_statement)
      allow(fake_statement).to receive(:fetch_all).and_return(row_data)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT id, name FROM users")
          result = statement.fetch_all
          expect(result).to eq(row_data) # Should return original result
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      # Check command log entry
      fetch_command = commands.find { |cmd| cmd["method"] == "fetch_all" }

      aggregate_failures do
        expect(fetch_command).not_to be_nil
        expect(fetch_command["method"]).to eq("fetch_all")
        expect(fetch_command["statement_id"]).to eq("stmt_0")
        expect(fetch_command["rows_file"]).to eq("rows_0.csv")
      end

      # Check CSV file was created with correct data
      csv_file = File.join(cassette_path, "rows_0.csv")
      expect(File.exist?(csv_file)).to be true

      csv_content = CSV.read(csv_file)
      expect(csv_content).to eq(row_data)
    end

    it "handles empty result sets" do # rubocop:disable RSpec/ExampleLength
      allow(fake_db).to receive(:run).with("SELECT * FROM empty_table").and_return(fake_statement)
      allow(fake_statement).to receive(:fetch_all).and_return([])

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM empty_table")
          result = statement.fetch_all
          expect(result).to eq([])
        end
      end

      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      fetch_command = commands.find { |cmd| cmd["method"] == "fetch_all" }
      expect(fetch_command["rows_file"]).to eq("rows_0.csv")

      # CSV file should exist but be empty
      csv_file = File.join(cassette_path, "rows_0.csv")
      expect(File.exist?(csv_file)).to be true
      expect(CSV.read(csv_file)).to eq([])
    end

    it "normalizes nil results to empty arrays" do # rubocop:disable RSpec/ExampleLength
      query = "SELECT * FROM truly_empty_table"
      allow(fake_db).to receive(:run).with(query).and_return(fake_statement)
      allow(fake_statement).to receive(:fetch_all).and_return(nil)

      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run(query)
          result = statement.fetch_all
          expect(result).to be_nil # Should still return original nil
        end
      end

      # But in the cassette, it should be stored as empty array
      csv_file = File.join(cassette_path, "rows_0.csv")
      expect(File.exist?(csv_file)).to be true
      expect(CSV.read(csv_file)).to eq([]) # Stored as empty array
    end

    describe "multiple fetch_all calls with sequential file naming" do
      let(:row_data1) { [["001", "Alice"]] } # rubocop:disable RSpec/IndexedLet
      let(:row_data2) { [["002", "Bob"], ["003", "Charlie"]] } # rubocop:disable RSpec/IndexedLet

      before do
        fake_statement1 = instance_double(ODBC::Statement)
        fake_statement2 = instance_double(ODBC::Statement)
        allow(fake_statement1).to receive(:fetch_all).and_return(row_data1)
        allow(fake_statement2).to receive(:fetch_all).and_return(row_data2)
        allow(fake_db).to receive(:run).with("SELECT * FROM users").and_return(fake_statement1)
        allow(fake_db).to receive(:run).with("SELECT * FROM orders").and_return(fake_statement2)

        Super8.use_cassette(cassette_name) do
          ODBC.connect("retalix") do |db|
            stmt1 = db.run("SELECT * FROM users")
            stmt1.fetch_all
            stmt2 = db.run("SELECT * FROM orders")
            stmt2.fetch_all
          end
        end
      end

      it "creates CSV files with sequential numbering" do
        expect(File.exist?(File.join(cassette_path, "rows_0.csv"))).to be true
        expect(File.exist?(File.join(cassette_path, "rows_1.csv"))).to be true
      end

      it "writes correct data to sequentially numbered CSV files" do
        expect(CSV.read(File.join(cassette_path, "rows_0.csv"))).to eq(row_data1)
        expect(CSV.read(File.join(cassette_path, "rows_1.csv"))).to eq(row_data2)
      end

      it "records commands with sequential file references" do
        commands = YAML.load_file(File.join(cassette_path, "commands.yml"))
        fetch_commands = commands.select { |cmd| cmd["method"] == "fetch_all" }
        expect(fetch_commands[0]["rows_file"]).to eq("rows_0.csv")
        expect(fetch_commands[1]["rows_file"]).to eq("rows_1.csv")
      end
    end
  end

  describe "Statement#drop" do
    let(:fake_statement_result) { "un-deserializable test double" }

    before do
      allow(fake_db).to receive(:run).and_return(fake_statement)
      allow(fake_statement).to receive(:drop).and_return(fake_statement_result)
    end

    it "records drop call and returns original result" do
      result = nil
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM users")
          result = statement.drop
        end
      end

      # Should return the original result
      expect(result).to eq(fake_statement_result)

      # Should record the drop command
      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      drop_command = commands.find { |cmd| cmd["method"] == "drop" }
      expect(drop_command).not_to be_nil

      aggregate_failures do
        expect(drop_command["method"]).to eq("drop")
        expect(drop_command["statement_id"]).to eq("stmt_0")
        expect(drop_command).not_to have_key("result")
      end
    end
  end

  describe "Statement#cancel" do
    let(:fake_cancel_result) { "cancel_result" }

    before do
      allow(fake_db).to receive(:run).and_return(fake_statement)
      allow(fake_statement).to receive(:cancel).and_return(fake_cancel_result)
    end

    it "records cancel call and returns original result" do
      result = nil
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM users")
          result = statement.cancel
        end
      end

      # Should return the original result
      expect(result).to eq(fake_cancel_result)

      # Should record the cancel command
      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      cancel_command = commands.find { |cmd| cmd["method"] == "cancel" }
      expect(cancel_command).not_to be_nil

      aggregate_failures do
        expect(cancel_command["method"]).to eq("cancel")
        expect(cancel_command["statement_id"]).to eq("stmt_0")
        expect(cancel_command).not_to have_key("result")
      end
    end
  end

  describe "Statement#close" do
    let(:fake_close_result) { "close_result" }

    before do
      allow(fake_db).to receive(:run).and_return(fake_statement)
      allow(fake_statement).to receive(:close).and_return(fake_close_result)
    end

    it "records close call and returns original result" do
      result = nil
      Super8.use_cassette(cassette_name) do
        ODBC.connect("retalix") do |db|
          statement = db.run("SELECT * FROM users")
          result = statement.close
        end
      end

      # Should return the original result
      expect(result).to eq(fake_close_result)

      # Should record the close command
      commands_file = File.join(cassette_path, "commands.yml")
      commands = YAML.load_file(commands_file)

      close_command = commands.find { |cmd| cmd["method"] == "close" }
      expect(close_command).not_to be_nil

      aggregate_failures do
        expect(close_command["method"]).to eq("close")
        expect(close_command["statement_id"]).to eq("stmt_0")
        expect(close_command).not_to have_key("result")
      end
    end
  end
end
