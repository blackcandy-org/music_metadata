# frozen_string_literal: true

require "test_helper"

class MetadataMergerTest < Minitest::Test
  def test_normalizes_aliases_and_preserves_embedded_values_when_remote_values_are_blank
    merger = MusicMetadata::MetadataMerger.new(
      embedded: {name: "Local title", genre: "Rock", image: "local.jpg"}
    )

    merger.merge_recording(
      {
        title: nil,
        artists: [],
        genres: [],
        release: {title: "Remote album", date: "1999"}
      },
      candidate: nil
    )
    metadata, sources = merger.to_h

    assert_equal "Local title", metadata[:title]
    assert_equal ["Rock"], metadata[:genres]
    assert_equal "local.jpg", metadata[:artwork]
    assert_equal "Remote album", metadata[:album]
    assert_equal 1999, metadata[:year]
    assert_equal :embedded, sources[:title]
  end
end
