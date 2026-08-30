# frozen_string_literal: true

module MusicMetadata
  module Providers
    class MusicBrainz
      ENDPOINT = "https://musicbrainz.org/ws/2"

      def initialize(http:)
        @http = http
      end

      def recording(recording_id, album_hint: nil)
        response = @http.get_json(
          "#{ENDPOINT}/recording/#{recording_id}",
          params: {
            fmt: "json",
            inc: "artist-credits+releases+isrcs+genres+tags"
          }
        )
        release = select_release(response.fetch(:releases, []), album_hint)
        artist_credit = response.fetch(:"artist-credit", [])

        {
          musicbrainz_recording_id: response[:id],
          title: response[:title],
          artists: artist_credit.filter_map { |credit| credit.dig(:artist, :name) || credit[:name] },
          artist_credit: format_artist_credit(artist_credit),
          isrcs: response.fetch(:isrcs, []),
          genres: extract_genres(response),
          release: normalize_release(release)
        }
      end

      private

      def select_release(releases, album_hint)
        hint = normalize(album_hint)
        releases.max_by do |release|
          score = 0
          score += 4 if !hint.empty? && normalize(release[:title]) == hint
          score += 2 if release[:status] == "Official"
          score += 1 unless release[:date].to_s.empty?
          score
        end
      end

      def normalize_release(release)
        return {} unless release

        {
          musicbrainz_release_id: release[:id],
          title: release[:title],
          date: release[:date],
          country: release[:country],
          status: release[:status]
        }.compact
      end

      def extract_genres(response)
        genres = response.fetch(:genres, [])
        genres = response.fetch(:tags, []) if genres.empty?
        genres
          .sort_by { |genre| -genre.fetch(:count, 0).to_i }
          .filter_map { |genre| genre[:name] }
          .uniq
      end

      def format_artist_credit(credits)
        credits.map do |credit|
          name = credit[:name] || credit.dig(:artist, :name)
          "#{name}#{credit[:joinphrase]}"
        end.join
      end

      def normalize(value)
        value.to_s.downcase.gsub(/[^[:alnum:]]+/, " ").strip
      end
    end
  end
end
