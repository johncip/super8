require "super8"
require "fakefs/spec_helpers"

RSpec.describe Super8::Cassette do
  include FakeFS::SpecHelpers

  let(:cassette_dir) { "spec/super8_cassettes" }

  before { Super8.config.cassette_directory = cassette_dir }

  describe "#path" do
    it "joins cassette_directory with the cassette name" do
      cassette = described_class.new("my_cassette")
      expect(cassette.path).to eq("spec/super8_cassettes/my_cassette")
    end
  end

  describe "#exists?" do
    it "returns false when directory does not exist" do
      cassette = described_class.new("missing")
      expect(cassette.exists?).to be false
    end

    it "returns true when directory exists" do
      FileUtils.mkdir_p("#{cassette_dir}/existing")
      cassette = described_class.new("existing")
      expect(cassette.exists?).to be true
    end
  end

  describe "#save" do
    it "creates the cassette directory" do
      cassette = described_class.new("new_cassette")
      cassette.save
      expect(Dir.exist?("#{cassette_dir}/new_cassette")).to be true
    end

    it "creates parent directories as needed" do
      Super8.config.cassette_directory = "deep/nested/cassettes"
      cassette = described_class.new("test")
      cassette.save
      expect(Dir.exist?("deep/nested/cassettes/test")).to be true
    end

    it "creates metadata.yml" do
      cassette = described_class.new("test_metadata")
      cassette.save
      expect(File.exist?("#{cassette_dir}/test_metadata/metadata.yml")).to be true
    end
  end

  describe "#load" do
    it "raises CassetteNotFoundError when cassette does not exist" do
      cassette = described_class.new("missing")
      expect { cassette.load }.to raise_error(
        Super8::CassetteNotFoundError,
        /Cassette not found:.*missing/
      )
    end

    it "loads cassettes and allows playback" do
      FileUtils.mkdir_p("#{cassette_dir}/test_cassette")
      commands = [
        {"method" => "connect", "connection_id" => "a", "dsn" => "test"},
        {"method" => "run", "connection_id" => "a", "statement_id" => 1}
      ]
      File.write("#{cassette_dir}/test_cassette/commands.yml", commands.to_yaml)
      
      cassette = described_class.new("test_cassette")
      cassette.load
      
      expect(cassette.next_command["method"]).to eq("connect")
      expect(cassette.next_command["method"]).to eq("run")
    end
  end
end
