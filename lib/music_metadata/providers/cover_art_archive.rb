# frozen_string_literal: true

module MusicMetadata
  module Providers
    class CoverArtArchive
      ENDPOINT = "https://coverartarchive.org/release"

      def initialize(http:)
        @http = http
      end

      def front(release_id)
        return if release_id.nil? || release_id.empty?

        response = @http.get_json("#{ENDPOINT}/#{release_id}", allow_not_found: true)
        return unless response

        image = response.fetch(:images, []).find { |item| item[:front] && item.fetch(:approved, true) }
        image ||= response.fetch(:images, []).find { |item| item[:front] }
        return unless image

        thumbnails = image.fetch(:thumbnails, {})
        {
          url: thumbnails[:"500"] || thumbnails[:large] || thumbnails[:"250"] || image[:image],
          original_url: image[:image],
          source: :cover_art_archive,
          approved: image.fetch(:approved, false)
        }
      end
    end
  end
end
