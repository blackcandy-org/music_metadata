# frozen_string_literal: true

module MusicMetadata
  class Result
    attr_reader :metadata, :sources, :confidence, :match_method, :candidates,
      :warnings

    def initialize(metadata:, sources:, confidence:, match_method:, candidates:, warnings: [], minimum_confidence: 0.85, ambiguity_window: 0.03)
      @metadata = deep_freeze(metadata)
      @sources = deep_freeze(sources)
      @confidence = confidence
      @match_method = match_method
      @candidates = candidates.freeze
      @warnings = warnings.freeze
      @minimum_confidence = minimum_confidence
      @ambiguity_window = ambiguity_window
      freeze
    end

    def matched?
      !confidence.nil?
    end

    def acceptable?
      matched? && confidence >= @minimum_confidence && !ambiguous?
    end

    def ambiguous?
      return false if candidates.length < 2

      candidates[0].score - candidates[1].score <= @ambiguity_window
    end

    def value(field)
      metadata[field.to_sym]
    end

    def source(field)
      sources[field.to_sym]
    end

    def to_h
      {
        metadata: metadata,
        sources: sources,
        match: {
          confidence: confidence,
          method: match_method,
          acceptable: acceptable?,
          ambiguous: ambiguous?
        },
        candidates: candidates.map(&:to_h),
        warnings: warnings
      }
    end

    private

    def deep_freeze(value)
      case value
      when Hash
        value.transform_values { |item| deep_freeze(item) }.freeze
      when Array
        value.map { |item| deep_freeze(item) }.freeze
      else
        value.freeze
      end
    end
  end
end
