# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_defaults_are_safe_for_public_services
    configuration = MusicMetadata::Configuration.new

    assert_equal 1.0, configuration.musicbrainz_interval
    assert_in_delta 1.0 / 3, configuration.acoustid_interval
    assert_equal 2, configuration.max_retries
    assert_instance_of MusicMetadata::MemoryCache, configuration.cache
  end

  def test_requires_an_acoustid_application_key
    configuration = MusicMetadata::Configuration.new
    configuration.acoustid_api_key = " "

    assert_raises(MusicMetadata::ConfigurationError) { configuration.validate_acoustid! }
  end

  def test_rejects_invalid_runtime_settings
    configuration = MusicMetadata::Configuration.new
    configuration.minimum_confidence = 1.1

    error = assert_raises(MusicMetadata::ConfigurationError) { configuration.validate_http! }

    assert_match "minimum_confidence", error.message
  end

  def test_requires_a_user_agent_and_positive_timeouts
    configuration = MusicMetadata::Configuration.new
    configuration.user_agent = ""
    assert_raises(MusicMetadata::ConfigurationError) { configuration.validate_http! }

    configuration.user_agent = "Test/1.0 (test@example.com)"
    configuration.request_timeout = 0
    error = assert_raises(MusicMetadata::ConfigurationError) { configuration.validate_http! }
    assert_match "request_timeout", error.message
  end
end
