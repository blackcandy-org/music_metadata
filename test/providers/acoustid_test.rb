# frozen_string_literal: true

require "test_helper"

class AcoustIDTest < Minitest::Test
  def test_returns_deduplicated_candidates_sorted_by_score
    http = FakeHttp.new(
      MusicMetadata::Providers::AcoustID::ENDPOINT => {
        status: "ok",
        results: [
          {
            id: "acoustid-low",
            score: 0.72,
            recordings: [ { id: "recording-1", title: "Song", artists: [ { name: "Artist" } ] } ]
          },
          {
            id: "acoustid-high",
            score: 0.97,
            recordings: [ { id: "recording-1", title: "Song", artists: [ { name: "Artist" } ] } ]
          },
          {
            id: "acoustid-second",
            score: 0.91,
            recordings: [ { id: "recording-2", title: "Other", artists: [] } ]
          }
        ]
      }
    )
    provider = MusicMetadata::Providers::AcoustID.new(http: http, api_key: "key")

    candidates = provider.lookup(MusicMetadata::Fingerprint.new(duration: 200, value: "abc"))

    assert_equal [ "recording-1", "recording-2" ], candidates.map(&:recording_id)
    assert_in_delta 0.97, candidates.first.score
    assert_equal "acoustid-high", candidates.first.acoustid
    assert_equal "key", http.requests.first[:params][:client]
    assert_equal "recordings releasegroups releases compress", http.requests.first[:params][:meta]
  end

  def test_raises_when_acoustid_reports_an_error
    http = FakeHttp.new(
      MusicMetadata::Providers::AcoustID::ENDPOINT => {
        status: "error",
        error: { message: "invalid key" }
      }
    )

    error = assert_raises(MusicMetadata::ProviderError) do
      MusicMetadata::Providers::AcoustID.new(http: http, api_key: "bad")
        .lookup(MusicMetadata::Fingerprint.new(duration: 1, value: "abc"))
    end

    assert_match "invalid key", error.message
  end
end
