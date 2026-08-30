# frozen_string_literal: true

require "test_helper"

class MusicMetadataTest < Minitest::Test
  def teardown
    MusicMetadata.reset_configuration!
  end

  def test_configure_and_reset_configuration
    original = MusicMetadata.configuration

    configured = MusicMetadata.configure { |configuration| configuration.cache_ttl = 12 }
    assert_same original, configured
    assert_equal 12, MusicMetadata.configuration.cache_ttl

    MusicMetadata.reset_configuration!
    refute_same original, MusicMetadata.configuration
  end

  def test_enrich_delegates_to_an_enricher
    MusicMetadata.configure { |configuration| configuration.acoustid_api_key = "key" }
    fingerprinter = Object.new
    fingerprinter.define_singleton_method(:call) do |_path|
      MusicMetadata::Fingerprint.new(duration: 100, value: "fingerprint")
    end
    acoustid = Object.new
    acoustid.define_singleton_method(:lookup) do |_fingerprint|
      [MusicMetadata::Candidate.new(recording_id: "recording", score: 0.99)]
    end
    musicbrainz = Object.new
    musicbrainz.define_singleton_method(:recording) do |_id, **_hints|
      {musicbrainz_recording_id: "recording", title: "Canonical", release: {}}
    end
    cover_art = Object.new
    cover_art.define_singleton_method(:front) { |_release_id| nil }

    result = MusicMetadata.enrich(
      file_path: "song.mp3",
      metadata: {title: "Song"},
      fingerprinter: fingerprinter,
      acoustid: acoustid,
      musicbrainz: musicbrainz,
      cover_art: cover_art,
      http: FakeHttp.new
    )

    assert_kind_of MusicMetadata::Result, result
    assert_equal "Canonical", result.value(:title)
  end
end
