# frozen_string_literal: true

require "test_helper"

class CoverArtArchiveTest < Minitest::Test
  def test_returns_preferred_front_thumbnail
    url = "#{MusicMetadata::Providers::CoverArtArchive::ENDPOINT}/release-1"
    http = FakeHttp.new(
      url => {
        images: [
          {
            front: true,
            approved: true,
            image: "https://images.example/original.jpg",
            thumbnails: {"250": "https://images.example/250.jpg", "500": "https://images.example/500.jpg"}
          }
        ]
      }
    )

    art = MusicMetadata::Providers::CoverArtArchive.new(http: http).front("release-1")

    assert_equal "https://images.example/500.jpg", art[:url]
    assert_equal :cover_art_archive, art[:source]
    assert http.requests.first[:allow_not_found]
  end

  def test_returns_nil_when_release_has_no_art
    url = "#{MusicMetadata::Providers::CoverArtArchive::ENDPOINT}/missing"
    http = FakeHttp.new(url => nil)

    assert_nil MusicMetadata::Providers::CoverArtArchive.new(http: http).front("missing")
  end
end
