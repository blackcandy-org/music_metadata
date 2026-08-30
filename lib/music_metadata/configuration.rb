# frozen_string_literal: true

module MusicMetadata
  class Configuration
    attr_accessor :acoustid_api_key, :user_agent, :minimum_confidence,
      :ambiguity_window, :request_timeout, :musicbrainz_interval,
      :fpcalc_path

    def initialize
      @acoustid_api_key = ENV["ACOUSTID_API_KEY"]
      @user_agent = ENV.fetch(
        "MUSIC_METADATA_USER_AGENT",
        "music_metadata/#{MusicMetadata::VERSION} (https://github.com/blackcandy-org/music_metadata)"
      )
      @minimum_confidence = 0.85
      @ambiguity_window = 0.03
      @request_timeout = 10
      @musicbrainz_interval = 1.0
      @fpcalc_path = ENV.fetch("FPCALC_PATH", "fpcalc")
    end

    def validate_http!
      if user_agent.nil? || user_agent.strip.empty?
        raise ConfigurationError, "A descriptive User-Agent is required"
      end

      self
    end

    def validate_acoustid!
      if acoustid_api_key.nil? || acoustid_api_key.strip.empty?
        raise ConfigurationError, "AcoustID API key is required"
      end

      self
    end
  end
end
