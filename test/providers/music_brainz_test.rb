# frozen_string_literal: true

require "test_helper"

class MusicBrainzTest < Minitest::Test
  def test_normalizes_recording_and_prefers_release_matching_album_hint
    url = "#{MusicMetadata::Providers::MusicBrainz::ENDPOINT}/recording/recording-1"
    http = FakeHttp.new(
      url => {
        id: "recording-1",
        title: "A Song",
        "artist-credit": [
          {name: "Artist One", joinphrase: " & ", artist: {name: "Artist One"}},
          {name: "Artist Two", artist: {name: "Artist Two"}}
        ],
        isrcs: ["USABC1234567"],
        genres: [{name: "Rock", count: 4}, {name: "Indie", count: 8}],
        releases: [
          {id: "wrong", title: "Compilation", status: "Official"},
          {id: "right", title: "The Album!", status: "Official", date: "2020-05-01", country: "US"}
        ]
      }
    )

    result = MusicMetadata::Providers::MusicBrainz.new(http: http)
      .recording("recording-1", album_hint: "the album")

    assert_equal "Artist One & Artist Two", result[:artist_credit]
    assert_equal ["Indie", "Rock"], result[:genres]
    assert_equal "right", result.dig(:release, :musicbrainz_release_id)
    assert_equal "2020-05-01", result.dig(:release, :date)
  end

  def test_release_id_hint_wins_and_selection_is_deterministic
    url = "#{MusicMetadata::Providers::MusicBrainz::ENDPOINT}/recording/recording-1"
    http = FakeHttp.new(
      url => {
        id: "recording-1",
        title: "A Song",
        releases: [
          {id: "later", title: "Album", status: "Official", date: "2021-01-01"},
          {id: "earlier", title: "Album", status: "Official", date: "2020-01-01"},
          {id: "wanted", title: "Different", status: "Promotion", date: "2022-01-01"}
        ]
      }
    )
    provider = MusicMetadata::Providers::MusicBrainz.new(http: http)

    hinted = provider.recording("recording-1", album_hint: "Album", release_id_hint: "wanted")
    unhinted = provider.recording("recording-1", album_hint: "Album")

    assert_equal "wanted", hinted.dig(:release, :musicbrainz_release_id)
    assert_equal "earlier", unhinted.dig(:release, :musicbrainz_release_id)
    assert_includes http.requests.first[:params][:inc], "release-groups"
  end
end
