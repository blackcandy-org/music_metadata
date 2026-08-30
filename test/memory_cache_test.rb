# frozen_string_literal: true

require "test_helper"

class MemoryCacheTest < Minitest::Test
  def test_expires_entries_and_evicts_least_recently_used_entry
    now = 10.0
    cache = MusicMetadata::MemoryCache.new(max_size: 2, clock: ->(*) { now })

    cache.write("one", 1, ttl: 10)
    cache.write("two", 2, ttl: 10)
    assert_equal 1, cache.read("one")

    cache.write("three", 3, ttl: 10)
    assert_nil cache.read("two")
    assert_equal 3, cache.read("three")

    now = 21.0
    assert_nil cache.read("one")
  end

  def test_clear_removes_entries
    cache = MusicMetadata::MemoryCache.new
    cache.write("key", "value", ttl: 10)

    cache.clear

    assert_nil cache.read("key")
  end
end
