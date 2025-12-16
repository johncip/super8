module Super8
  # Configuration class for Super8 settings.
  class Config
    attr_accessor :cassette_directory, :record_mode, :encoding

    def initialize
      @cassette_directory = "spec/super8_cassettes"
      @record_mode = :once
      @encoding = "utf-8"
    end
  end
end
