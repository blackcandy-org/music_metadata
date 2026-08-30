# frozen_string_literal: true

module MusicMetadata
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class FingerprintError < Error; end
  class ProviderError < Error; end

  class HttpError < ProviderError
    attr_reader :status, :body

    def initialize(message, status:, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end
end
