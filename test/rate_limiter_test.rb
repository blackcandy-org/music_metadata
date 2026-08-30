# frozen_string_literal: true

require "test_helper"

class RateLimiterTest < Minitest::Test
  def test_waits_for_the_remaining_interval
    now = 10.0
    sleeps = []
    limiter = MusicMetadata::RateLimiter.new(
      interval: 1.0,
      clock: ->(*) { now },
      sleeper: lambda do |duration|
        sleeps << duration
        now += duration
      end
    )

    limiter.wait
    now += 0.25
    limiter.wait

    assert_in_delta 0.75, sleeps.first
  end

  def test_shared_returns_the_same_limiter_for_a_host_and_interval
    MusicMetadata::RateLimiter.clear_shared!

    first = MusicMetadata::RateLimiter.shared("example.org", interval: 1)
    second = MusicMetadata::RateLimiter.shared("example.org", interval: 1)

    assert_same first, second
  ensure
    MusicMetadata::RateLimiter.clear_shared!
  end
end
