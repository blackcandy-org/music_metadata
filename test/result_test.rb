# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def test_result_data_is_deeply_frozen
    result = MusicMetadata::Result.new(
      metadata: { genres: [ "Rock" ] },
      sources: { genres: :musicbrainz },
      confidence: 0.9,
      match_method: :acoustid,
      candidates: [],
      minimum_confidence: 0.85
    )

    assert_raises(FrozenError) { result.metadata[:genres] << "Pop" }
  end
end
