# frozen_string_literal: true

require "json"
require "open3"

module MusicMetadata
  class Fingerprint
    attr_reader :duration, :value

    def initialize(duration:, value:)
      @duration = duration
      @value = value.dup.freeze
      freeze
    end
  end

  class Fingerprinter
    TERMINATION_GRACE = 1

    def initialize(executable: "fpcalc", timeout: 30)
      @executable = executable
      @timeout = timeout
    end

    def call(file_path)
      path = File.expand_path(file_path)
      raise FingerprintError, "Audio file does not exist: #{path}" unless File.file?(path)

      stdout, stderr, status = capture(path)
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

    private

    def capture(path)
      Open3.popen3(@executable, "-json", path, pgroup: true) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        stdout_reader = Thread.new { stdout.read }
        stderr_reader = Thread.new { stderr.read }

        unless wait_thread.join(@timeout)
          terminate(wait_thread)
          stdout_reader.join
          stderr_reader.join
          raise FingerprintError, "fpcalc timed out after #{@timeout} seconds"
        end

        [stdout_reader.value, stderr_reader.value, wait_thread.value]
      end
    end

    def terminate(wait_thread)
      Process.kill("TERM", -wait_thread.pid)
      return if wait_thread.join(TERMINATION_GRACE)

      Process.kill("KILL", -wait_thread.pid)
      wait_thread.join
    rescue Errno::ESRCH
      nil
    end
  end
end
