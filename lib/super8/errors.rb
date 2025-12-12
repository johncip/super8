module Super8
  # Base error class for Super 8 exceptions.
  class Error < StandardError; end

  # Raised when a requested cassette is not found on disk.
  class CassetteNotFoundError < Error; end

  # Raised when playback interactions don't match recorded commands.
  class CommandMismatchError < Error; end
end
