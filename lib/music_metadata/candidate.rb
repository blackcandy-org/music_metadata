# frozen_string_literal: true

module MusicMetadata
  Candidate = Struct.new(
    :recording_id,
    :score,
    :title,
    :artists,
    :acoustid,
    keyword_init: true
  ) do
    def to_h
      {
        recording_id: recording_id,
        score: score,
        title: title,
        artists: artists,
        acoustid: acoustid
      }
    end
  end
end
