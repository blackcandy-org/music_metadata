# frozen_string_literal: true

module MusicMetadata
  module Providers
    class AcoustID
      ENDPOINT = "https://api.acoustid.org/v2/lookup"

      def initialize(http:, api_key:)
        @http = http
        @api_key = api_key
      end

      def lookup(fingerprint)
        response = @http.get_json(
          ENDPOINT,
          params: {
            client: @api_key,
            duration: fingerprint.duration,
            fingerprint: fingerprint.value,
            # URI.encode_www_form escapes literal plus signs. AcoustID expects
            # meta fields separated by whitespace (encoded as `+` on the wire).
            meta: "recordings releasegroups releases compress"
          }
        )
        unless response[:status] == "ok"
          message = response.dig(:error, :message) || "unknown AcoustID error"
          raise ProviderError, "AcoustID lookup failed: #{message}"
        end

        candidates = response.fetch(:results, []).flat_map do |result|
          result.fetch(:recordings, []).map do |recording|
            Candidate.new(
              recording_id: recording[:id],
              score: result[:score].to_f,
              title: recording[:title],
              artists: recording.fetch(:artists, []).filter_map { |artist| artist[:name] },
              acoustid: result[:id]
            )
          end
        end

        candidates
          .reject { |candidate| candidate.recording_id.nil? }
          .group_by(&:recording_id)
          .map { |_id, matches| matches.max_by(&:score) }
          .sort_by { |candidate| -candidate.score }
      end
    end
  end
end
