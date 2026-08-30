# frozen_string_literal: true

module MusicMetadata
  class Enricher
    def initialize(configuration:, http: nil, fingerprinter: nil, acoustid: nil, musicbrainz: nil, cover_art: nil)
      @configuration = configuration
      @configuration.validate_http!
      @http = http || build_http
      @fingerprinter = fingerprinter || Fingerprinter.new(
        executable: configuration.fpcalc_path,
        timeout: configuration.fingerprint_timeout
      )
      @acoustid = acoustid
      @musicbrainz = musicbrainz || Providers::MusicBrainz.new(http: @http)
      @cover_art = cover_art || Providers::CoverArtArchive.new(http: @http)
    end

    def call(file_path:, metadata: {})
      embedded = symbolize_keys(metadata)
      candidates, match_method = identify(file_path, embedded)
      candidate = candidates.first
      return unmatched_result(embedded) unless candidate

      recording = @musicbrainz.recording(
        candidate.recording_id,
        album_hint: embedded[:album] || embedded[:album_name],
        release_id_hint: embedded[:musicbrainz_release_id]
      )
      merger = MetadataMerger.new(embedded: embedded)
      merger.merge_recording(recording, candidate: candidate)
      warnings = []

      release_id = recording.dig(:release, :musicbrainz_release_id)
      begin
        merger.merge_artwork(@cover_art.front(release_id))
      rescue ProviderError => error
        warnings << "Artwork lookup failed: #{error.message}"
      end

      normalized, sources = merger.to_h
      Result.new(
        metadata: normalized,
        sources: sources,
        confidence: candidate.score,
        match_method: match_method,
        candidates: candidates,
        warnings: warnings,
        minimum_confidence: @configuration.minimum_confidence,
        ambiguity_window: @configuration.ambiguity_window
      )
    end

    private

    def identify(file_path, embedded)
      recording_id = embedded[:musicbrainz_recording_id]
      if recording_id && !recording_id.to_s.empty?
        candidate = Candidate.new(
          recording_id: recording_id,
          score: 1.0,
          title: embedded[:title] || embedded[:name],
          artists: Array(embedded[:artist] || embedded[:artist_name]),
          acoustid: embedded[:acoustid]
        )
        return [[candidate], :embedded_identifier]
      end

      @configuration.validate_acoustid!
      fingerprint = @fingerprinter.call(file_path)
      provider = @acoustid || Providers::AcoustID.new(
        http: @http,
        api_key: @configuration.acoustid_api_key
      )
      [provider.lookup(fingerprint), :acoustid]
    end

    def unmatched_result(embedded)
      metadata, sources = MetadataMerger.new(embedded: embedded).to_h
      Result.new(
        metadata: metadata,
        sources: sources,
        confidence: nil,
        match_method: nil,
        candidates: [],
        warnings: ["No AcoustID match was found"],
        minimum_confidence: @configuration.minimum_confidence,
        ambiguity_window: @configuration.ambiguity_window
      )
    end

    def build_http
      HttpClient.new(
        user_agent: @configuration.user_agent,
        timeout: @configuration.request_timeout,
        limiters: {
          "musicbrainz.org" => RateLimiter.shared(
            "musicbrainz.org",
            interval: @configuration.musicbrainz_interval
          ),
          "api.acoustid.org" => RateLimiter.shared(
            "api.acoustid.org",
            interval: @configuration.acoustid_interval
          )
        },
        cache: @configuration.cache,
        cache_ttl: @configuration.cache_ttl,
        max_retries: @configuration.max_retries,
        retry_base_interval: @configuration.retry_base_interval,
        retry_max_interval: @configuration.retry_max_interval
      )
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) { |(key, value), result| result[key.to_sym] = value }
    end
  end
end
