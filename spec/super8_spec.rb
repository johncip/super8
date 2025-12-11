require "super8"

RSpec.describe Super8 do
  describe ".config" do
    it "returns a Config instance" do
      expect(described_class.config).to be_a(Super8::Config)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.config).to be(described_class.config) # rubocop:disable RSpec/IdenticalEqualityAssertion
    end
  end

  describe ".configure" do
    it "yields the config" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Super8::Config)
    end

    it "allows setting cassette_directory" do
      described_class.configure { |c| c.cassette_directory = "custom/path" }
      expect(described_class.config.cassette_directory).to eq("custom/path")
    end
  end

  describe ".use_cassette" do
    it "yields to the block" do
      called = false
      described_class.use_cassette("test") { called = true }
      expect(called).to be true
    end
  end
end
