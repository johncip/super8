require "super8"

RSpec.describe Super8 do
  describe ".config" do
    it "returns a Config instance" do
      expect(Super8.config).to be_a(Super8::Config)
    end

    it "returns the same instance on repeated calls" do
      expect(Super8.config).to be(Super8.config)
    end
  end

  describe ".configure" do
    it "yields the config" do
      expect { |b| Super8.configure(&b) }.to yield_with_args(Super8::Config)
    end

    it "allows setting cassette_directory" do
      Super8.configure { |c| c.cassette_directory = "custom/path" }
      expect(Super8.config.cassette_directory).to eq("custom/path")
    end
  end

  describe ".use_cassette" do
    it "yields to the block" do
      called = false
      Super8.use_cassette("test") { called = true }
      expect(called).to be true
    end
  end
end
