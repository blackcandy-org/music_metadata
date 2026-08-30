# frozen_string_literal: true

module MusicMetadata
  class MetadataMerger
    FIELD_ALIASES = {
      name: :title,
      artist_name: :artist,
      album_name: :album,
      year: :year,
      genre: :genres,
      image: :artwork
    }.freeze

    def initialize(embedded:)
      @metadata = {}
      @sources = {}
      normalize_embedded(embedded).each do |field, value|
        write(field, value, :embedded)
      end
    end

    def merge_recording(recording, candidate:)
      write(:title, recording[:title] || candidate&.title, :musicbrainz)
      write(:artists, recording[:artists], :musicbrainz)
      write(:artist, recording[:artist_credit] || recording[:artists]&.first, :musicbrainz)
      write(:genres, recording[:genres], :musicbrainz)
      write(:isrcs, recording[:isrcs], :musicbrainz)
      write(:musicbrainz_recording_id, recording[:musicbrainz_recording_id], :musicbrainz)
      write(:acoustid, candidate&.acoustid, :acoustid)

      release = recording.fetch(:release, {})
      write(:album, release[:title], :musicbrainz)
      write(:release_date, release[:date], :musicbrainz)
      write(:year, year_from(release[:date]), :musicbrainz)
      write(:country, release[:country], :musicbrainz)
      write(:musicbrainz_release_id, release[:musicbrainz_release_id], :musicbrainz)
      self
    end

    def merge_artwork(artwork)
      write(:artwork, artwork, :cover_art_archive)
      self
    end

    def to_h
      [ @metadata, @sources ]
    end

    private

    def normalize_embedded(embedded)
      embedded.each_with_object({}) do |(field, value), result|
        key = field.to_sym
        key = FIELD_ALIASES.fetch(key, key)
        value = Array(value) if key == :genres && !value.is_a?(Array)
        result[key] = value
      end
    end

    def write(field, value, source)
      return if blank?(value)

      @metadata[field] = value
      @sources[field] = source
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def year_from(date)
      match = date.to_s.match(/\A(\d{4})/)
      match && match[1].to_i
    end
  end
end
