# frozen_string_literal: true

require "test_helper"

class EnricherTest < Minitest::Test
  FakeFingerprinter = Struct.new(:fingerprint) do
    def call(_file_path)
      fingerprint
    end
  end

  FakeAcoustID = Struct.new(:candidates) do
    def lookup(_fingerprint)
      candidates
    end
  end

  FakeMusicBrainz = Struct.new(:response) do
    def recording(_recording_id, album_hint: nil)
      response.merge(album_hint_received: album_hint)
    end
  end

  FakeCoverArt = Struct.new(:response) do
    def front(_release_id)
      response
    end
  end

  def setup
    @configuration = MusicMetadata::Configuration.new
    @configuration.acoustid_api_key = "test-key"
    @configuration.musicbrainz_interval = 0
  end

  def test_enriches_and_tracks_field_provenance
    candidate = candidate(score: 0.97)
    enricher = build_enricher(
      candidates: [ candidate ],
      recording: recording,
      artwork: { url: "https://images.example/cover.jpg", source: :cover_art_archive }
    )

    result = enricher.call(
      file_path: "ignored.mp3",
      metadata: { name: "Old Title", artist_name: "Old Artist", album_name: "The Album", genre: "Old Genre" }
    )

    assert result.acceptable?
    assert_equal "Canonical Title", result.value(:title)
    assert_equal "Canonical Artist", result.value(:artist)
    assert_equal "The Album", result.value(:album)
    assert_equal 2020, result.value(:year)
    assert_equal :musicbrainz, result.source(:title)
    assert_equal :cover_art_archive, result.source(:artwork)
    assert_equal :acoustid, result.match_method
  end

  def test_marks_close_top_candidates_as_ambiguous
    result = build_enricher(
      candidates: [ candidate(score: 0.90), candidate(id: "recording-2", score: 0.88) ],
      recording: recording,
      artwork: nil
    ).call(file_path: "ignored.mp3")

    assert result.ambiguous?
    refute result.acceptable?
  end

  def test_returns_embedded_metadata_when_no_match_exists
    result = build_enricher(candidates: [], recording: recording, artwork: nil)
      .call(file_path: "ignored.mp3", metadata: { title: "Keep Me" })

    refute result.matched?
    assert_equal "Keep Me", result.value(:title)
    assert_equal :embedded, result.source(:title)
  end

  def test_known_recording_id_does_not_require_acoustid_key
    @configuration.acoustid_api_key = nil
    result = build_enricher(candidates: [], recording: recording, artwork: nil).call(
      file_path: "ignored.mp3",
      metadata: { musicbrainz_recording_id: "recording-1" }
    )

    assert result.acceptable?
    assert_equal :embedded_identifier, result.match_method
  end

  private

  def build_enricher(candidates:, recording:, artwork:)
    MusicMetadata::Enricher.new(
      configuration: @configuration,
      http: FakeHttp.new,
      fingerprinter: FakeFingerprinter.new(MusicMetadata::Fingerprint.new(duration: 200, value: "abc")),
      acoustid: FakeAcoustID.new(candidates),
      musicbrainz: FakeMusicBrainz.new(recording),
      cover_art: FakeCoverArt.new(artwork)
    )
  end

  def candidate(id: "recording-1", score:)
    MusicMetadata::Candidate.new(
      recording_id: id,
      score: score,
      title: "Candidate Title",
      artists: [ "Candidate Artist" ],
      acoustid: "acoustid-1"
    )
  end

  def recording
    {
      musicbrainz_recording_id: "recording-1",
      title: "Canonical Title",
      artists: [ "Canonical Artist" ],
      artist_credit: "Canonical Artist",
      isrcs: [ "USABC1234567" ],
      genres: [ "Indie Rock" ],
      release: {
        musicbrainz_release_id: "release-1",
        title: "The Album",
        date: "2020-05-01",
        country: "US",
        status: "Official"
      }
    }
  end
end
