# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def test_result_data_is_deeply_frozen
    result = MusicMetadata::Result.new(
      metadata: {genres: ["Rock"]},
      sources: {genres: :musicbrainz},
      confidence: 0.9,
      match_method: :acoustid,
      candidates: [],
      warnings: ["Provider warning"],
      minimum_confidence: 0.85
    )

    assert_raises(FrozenError) { result.metadata[:genres] << "Pop" }
    assert_raises(FrozenError) { result.warnings.first.replace("Changed") }
  end

  def test_candidate_is_immutable
    candidate = MusicMetadata::Candidate.new(
      recording_id: "recording",
      score: 0.9,
      artists: ["Artist"]
    )

    assert candidate.frozen?
    assert_raises(FrozenError) { candidate.artists << "Another" }
    assert_raises(FrozenError) { candidate.recording_id.replace("Changed") }
    assert_raises(FrozenError) { candidate.artists.first.replace("Changed") }
    assert_equal "recording", candidate.to_h[:recording_id]
  end

  def test_exposes_values_sources_and_serialized_match_state
    candidate = MusicMetadata::Candidate.new(recording_id: "one", score: 0.9)
    result = MusicMetadata::Result.new(
      metadata: {title: "Song"},
      sources: {title: :musicbrainz},
      confidence: 0.9,
      match_method: :acoustid,
      candidates: [candidate]
    )

    assert result.matched?
    assert_equal "Song", result.value("title")
    assert_equal :musicbrainz, result.source("title")
    assert_equal true, result.to_h.dig(:match, :acceptable)
  end
end
