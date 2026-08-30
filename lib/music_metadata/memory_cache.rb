# frozen_string_literal: true

module MusicMetadata
  class MemoryCache
    Entry = Struct.new(:value, :expires_at)

    def initialize(max_size: 256, clock: Process.method(:clock_gettime))
      raise ArgumentError, "max_size must be positive" unless max_size.positive?

      @max_size = max_size
      @clock = clock
      @entries = {}
      @mutex = Mutex.new
    end

    def read(key)
      @mutex.synchronize do
        entry = @entries.delete(key)
        return unless entry
        return if entry.expires_at <= monotonic_time

        @entries[key] = entry
        entry.value
      end
    end

    def write(key, value, ttl:)
      return value unless ttl.positive?

      @mutex.synchronize do
        @entries.delete(key)
        @entries[key] = Entry.new(value, monotonic_time + ttl)
        @entries.shift while @entries.size > @max_size
      end
      value
    end

    def clear
      @mutex.synchronize { @entries.clear }
    end

    private

    def monotonic_time
      @clock.call(Process::CLOCK_MONOTONIC)
    end
  end
end
