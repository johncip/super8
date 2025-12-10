require "super8/config"

RSpec.describe Super8::Config do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets cassette_directory to spec/super8_cassettes" do
      expect(config.cassette_directory).to eq("spec/super8_cassettes")
    end

    it "sets record_mode to :once" do
      expect(config.record_mode).to eq(:once)
    end
  end

  describe "accessors" do
    it "allows setting cassette_directory" do
      config.cassette_directory = "other/path"
      expect(config.cassette_directory).to eq("other/path")
    end

    it "allows setting record_mode" do
      config.record_mode = :none
      expect(config.record_mode).to eq(:none)
    end
  end
end
