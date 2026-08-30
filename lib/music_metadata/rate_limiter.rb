# frozen_string_literal: true

module MusicMetadata
  class RateLimiter
    def initialize(interval:, clock: Process.method(:clock_gettime), sleeper: Kernel.method(:sleep))
      @interval = interval
      @clock = clock
      @sleeper = sleeper
      @mutex = Mutex.new
      @last_request_at = nil
    end

    def wait
      return if @interval <= 0

      @mutex.synchronize do
        now = monotonic_time
        remaining = @last_request_at && (@interval - (now - @last_request_at))
        @sleeper.call(remaining) if remaining&.positive?
        @last_request_at = monotonic_time
      end
    end

    private

    def monotonic_time
      @clock.call(Process::CLOCK_MONOTONIC)
    end
  end
end
