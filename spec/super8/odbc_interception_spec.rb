require "spec_helper"
require "fakefs/spec_helpers"

RSpec.describe "ODBC.connect interception" do # rubocop:disable RSpec/DescribeClass
  include FakeFS::SpecHelpers

  let(:cassette_name) { "test_connection" }
  let(:cassette_dir) { Super8.config.cassette_directory }
  let(:cassette_path) { File.join(cassette_dir, cassette_name) }

  # Store original method to test restoration
  let(:original_connect) { ODBC.method(:connect) }

  it "saves DSN to connection.yml" do # rubocop:disable RSpec/ExampleLength
    # Use a test double to avoid real database connections
    fake_db = instance_double(ODBC::Database)

    allow(ODBC).to receive(:connect) do |_dsn, &block|
      block&.call(fake_db)
    end

    Super8.use_cassette(cassette_name) do
      ODBC.connect("retalix") {} # rubocop:disable Lint/EmptyBlock
    end

    connection_file = File.join(cassette_path, "connection.yml")
    connection_data = YAML.load_file(connection_file)
    expect(connection_data["dsn"]).to eq("retalix")
  end

  it "restores original ODBC.connect after use_cassette block" do # rubocop:disable RSpec/ExampleLength
    fake_db = instance_double(ODBC::Database)
    method_during_block = nil

    allow(ODBC).to receive(:connect) do |_dsn, &block|
      block&.call(fake_db)
    end

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
