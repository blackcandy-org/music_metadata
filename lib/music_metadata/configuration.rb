# frozen_string_literal: true

module MusicMetadata
  class Configuration
    attr_accessor :acoustid_api_key, :user_agent, :minimum_confidence,
      :ambiguity_window, :request_timeout, :musicbrainz_interval,
      :acoustid_interval, :max_retries, :retry_base_interval,
      :retry_max_interval, :cache, :cache_ttl, :fpcalc_path,
      :fingerprint_timeout

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
      @acoustid_interval = 1.0 / 3
      @max_retries = 2
      @retry_base_interval = 0.25
      @retry_max_interval = 30
      @cache = MemoryCache.new
      @cache_ttl = 3600
      @fpcalc_path = ENV.fetch("FPCALC_PATH", "fpcalc")
      @fingerprint_timeout = 30
    end

    def validate_http!
      if user_agent.nil? || user_agent.strip.empty?
        raise ConfigurationError, "A descriptive User-Agent is required"
      end

      validate_positive!(:request_timeout)
      validate_positive!(:fingerprint_timeout)
      validate_nonnegative!(:musicbrainz_interval)
      validate_nonnegative!(:acoustid_interval)
      validate_nonnegative!(:max_retries)
      validate_nonnegative!(:retry_base_interval)
      validate_nonnegative!(:retry_max_interval)
      validate_nonnegative!(:cache_ttl)
      validate_probability!(:minimum_confidence)
      validate_probability!(:ambiguity_window)

      self
    end

    def validate_acoustid!
      if acoustid_api_key.nil? || acoustid_api_key.strip.empty?
        raise ConfigurationError, "AcoustID API key is required"
      end

      self
    end

    private

    def validate_positive!(name)
      value = public_send(name)
      return if value.respond_to?(:positive?) && value.positive?

      raise ConfigurationError, "#{name} must be positive"
    end

    def validate_nonnegative!(name)
      value = public_send(name)
      return if value.is_a?(Numeric) && value >= 0

      raise ConfigurationError, "#{name} must be zero or greater"
    end

    def validate_probability!(name)
      value = public_send(name)
      return if value.is_a?(Numeric) && value.between?(0, 1)

      raise ConfigurationError, "#{name} must be between 0 and 1"
    end
  end
end
