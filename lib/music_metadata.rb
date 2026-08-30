# frozen_string_literal: true

require_relative "music_metadata/version"
require_relative "music_metadata/errors"
require_relative "music_metadata/configuration"
require_relative "music_metadata/candidate"
require_relative "music_metadata/result"
require_relative "music_metadata/rate_limiter"
require_relative "music_metadata/http_client"
require_relative "music_metadata/fingerprinter"
require_relative "music_metadata/providers/acoustid"
require_relative "music_metadata/providers/music_brainz"
require_relative "music_metadata/providers/cover_art_archive"
require_relative "music_metadata/metadata_merger"
require_relative "music_metadata/enricher"

module MusicMetadata
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def enrich(file_path:, metadata: {}, **dependencies)
      Enricher.new(configuration: configuration, **dependencies).call(
        file_path: file_path,
        metadata: metadata
      )
    end
  end
end
