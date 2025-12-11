module Super8
  # Configuration class for Super8 settings.
  class Config
    # :reek:Attribute
    attr_accessor :cassette_directory, :record_mode

    def initialize
      @cassette_directory = "spec/super8_cassettes"
      @record_mode = :once
    end
  end
end
