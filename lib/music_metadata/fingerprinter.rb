# frozen_string_literal: true

require "json"
require "open3"

module MusicMetadata
  Fingerprint = Struct.new(:duration, :value, keyword_init: true)

  class Fingerprinter
    def initialize(executable: "fpcalc")
      @executable = executable
    end

    def call(file_path)
      path = File.expand_path(file_path)
      raise FingerprintError, "Audio file does not exist: #{path}" unless File.file?(path)

      stdout, stderr, status = Open3.capture3(@executable, "-json", path)
      unless status.success?
        detail = stderr.strip
        detail = "exit status #{status.exitstatus}" if detail.empty?
        raise FingerprintError, "fpcalc failed: #{detail}"
      end

      parsed = JSON.parse(stdout, symbolize_names: true)
      duration = parsed[:duration]&.round
      value = parsed[:fingerprint]
      if !duration&.positive? || value.nil? || value.empty?
        raise FingerprintError, "fpcalc returned an incomplete fingerprint"
      end

      Fingerprint.new(duration: duration, value: value)
    rescue Errno::ENOENT
      raise FingerprintError, "fpcalc executable was not found at #{@executable.inspect}"
    rescue JSON::ParserError => error
      raise FingerprintError, "fpcalc returned invalid JSON: #{error.message}"
    end
  end
end
