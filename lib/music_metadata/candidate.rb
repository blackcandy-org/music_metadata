# frozen_string_literal: true

module MusicMetadata
  class Candidate
    attr_reader :recording_id, :score, :title, :artists, :acoustid

    def initialize(recording_id:, score:, title: nil, artists: [], acoustid: nil)
      @recording_id = immutable(recording_id)
      @score = score
      @title = immutable(title)
      @artists = Array(artists).map { |artist| immutable(artist) }.freeze
      @acoustid = immutable(acoustid)
      freeze
    end

    def to_h
      {
        recording_id: recording_id,
        score: score,
        title: title,
        artists: artists,
        acoustid: acoustid
      }
    end

    private

    def immutable(value)
      value.is_a?(String) ? value.dup.freeze : value
    end
  end
end
