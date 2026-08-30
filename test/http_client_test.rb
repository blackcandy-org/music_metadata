# frozen_string_literal: true

require "test_helper"

class HttpClientTest < Minitest::Test
  Response = Struct.new(:code, :body, :headers) do
    def [](name)
      headers&.fetch(name, nil)
    end
  end

  def test_get_parses_and_caches_successful_json
    cache = MusicMetadata::MemoryCache.new
    calls = 0
    client = build_client(cache: cache, cache_ttl: 60)
    client.define_singleton_method(:request) do |*_args, **_kwargs|
      calls += 1
      Response.new("200", '{"title":"Song"}', {})
    end

    first = client.get_json("https://example.org/song", params: {id: 1})
    second = client.get_json("https://example.org/song", params: {id: 1})

    assert_equal({title: "Song"}, first)
    assert_equal first, second
    assert_equal 1, calls
    assert first.frozen?
    assert first[:title].frozen?
  end

  def test_post_encodes_form_parameters_without_putting_them_in_the_url
    captured = nil
    client = build_client
    client.define_singleton_method(:request) do |method, uri, body:, **_kwargs|
      captured = {method: method, uri: uri, body: body}
      Response.new("200", '{"status":"ok"}', {})
    end

    client.post_form_json(
      "https://example.org/lookup",
      params: {client: "secret", fingerprint: "a+b c"}
    )

    assert_equal :post, captured[:method]
    assert_nil captured[:uri].query
    assert_equal "client=secret&fingerprint=a%2Bb+c", captured[:body]
  end

  def test_retries_transient_status_and_honors_retry_after
    responses = [
      Response.new("503", "busy", {"Retry-After" => "2"}),
      Response.new("200", '{"ok":true}', {})
    ]
    sleeps = []
    client = build_client(sleeper: ->(duration) { sleeps << duration }, random: ZeroRandom.new)
    client.define_singleton_method(:request) { |*_args, **_kwargs| responses.shift }

    result = client.get_json("https://example.org/data")

    assert_equal({ok: true}, result)
    assert_equal [2.0], sleeps
  end

  def test_caps_server_requested_retry_delay
    responses = [
      Response.new("429", "busy", {"Retry-After" => "600"}),
      Response.new("200", '{"ok":true}', {})
    ]
    sleeps = []
    client = build_client(
      retry_max_interval: 5,
      sleeper: ->(duration) { sleeps << duration },
      random: ZeroRandom.new
    )
    client.define_singleton_method(:request) { |*_args, **_kwargs| responses.shift }

    client.get_json("https://example.org/data")

    assert_equal [5], sleeps
  end

  def test_retries_network_errors_then_wraps_the_last_failure
    calls = 0
    client = build_client(max_retries: 1, sleeper: ->(*) {}, random: ZeroRandom.new)
    client.define_singleton_method(:request) do |*_args, **_kwargs|
      calls += 1
      raise SocketError, "offline"
    end

    error = assert_raises(MusicMetadata::ProviderError) do
      client.get_json("https://example.org/data")
    end

    assert_equal 2, calls
    assert_match "offline", error.message
  end

  def test_returns_nil_for_allowed_not_found
    client = build_client
    client.define_singleton_method(:request) do |*_args, **_kwargs|
      Response.new("404", "missing", {})
    end

    assert_nil client.get_json("https://example.org/missing", allow_not_found: true)
  end

  def test_raises_for_invalid_json_and_non_success_status
    invalid = build_client
    invalid.define_singleton_method(:request) do |*_args, **_kwargs|
      Response.new("200", "not json", {})
    end
    assert_raises(MusicMetadata::ProviderError) do
      invalid.get_json("https://example.org/data")
    end

    failing = build_client(max_retries: 0)
    failing.define_singleton_method(:request) do |*_args, **_kwargs|
      Response.new("401", "x" * 2_000, {})
    end
    error = assert_raises(MusicMetadata::HttpError) do
      failing.get_json("https://example.org/data")
    end

    assert_equal 401, error.status
    assert_equal 1_024, error.body.bytesize
  end

  def test_builds_real_post_request_with_headers_and_follows_303_as_get
    redirect = Net::HTTPSeeOther.new("1.1", "303", "See Other")
    redirect["location"] = "/result"
    success = net_response(Net::HTTPOK, "200", '{"ok":true}')
    responses = [redirect, success]
    requests = []
    limiter = Struct.new(:calls) do
      def wait
        self.calls += 1
      end
    end.new(0)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      requests << request
      responses.shift
    end
    starter = lambda do |*_args, **_kwargs, &block|
      block.call(fake_http)
    end
    client = MusicMetadata::HttpClient.new(
      user_agent: "Test/1.0 (test@example.com)",
      timeout: 1,
      limiters: {"example.org" => limiter}
    )

    result = Net::HTTP.stub(:start, starter) do
      client.post_form_json("https://example.org/lookup", params: {fingerprint: "abc"})
    end

    assert_equal({ok: true}, result)
    assert_instance_of Net::HTTP::Post, requests[0]
    assert_equal "fingerprint=abc", requests[0].body
    assert_equal "application/json", requests[0]["Accept"]
    assert_instance_of Net::HTTP::Get, requests[1]
    assert_equal 2, limiter.calls
  end

  def test_raises_after_too_many_redirects
    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["location"] = "/again"
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| redirect }
    starter = ->(*_args, **_kwargs, &block) { block.call(fake_http) }
    client = build_client

    error = Net::HTTP.stub(:start, starter) do
      assert_raises(MusicMetadata::ProviderError) do
        client.get_json("https://example.org/start")
      end
    end

    assert_match "Too many redirects", error.message
  end

  def test_refuses_to_forward_post_data_to_another_origin
    redirect = Net::HTTPTemporaryRedirect.new("1.1", "307", "Temporary Redirect")
    redirect["location"] = "https://other.example/result"
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| redirect }
    starter = ->(*_args, **_kwargs, &block) { block.call(fake_http) }
    client = build_client

    error = Net::HTTP.stub(:start, starter) do
      assert_raises(MusicMetadata::ProviderError) do
        client.post_form_json("https://example.org/lookup", params: {client: "secret"})
      end
    end

    assert_match "Refusing to forward POST data", error.message
  end

  def test_refuses_https_downgrade_redirects
    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["location"] = "http://example.org/result"
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| redirect }
    starter = ->(*_args, **_kwargs, &block) { block.call(fake_http) }
    client = build_client

    error = Net::HTTP.stub(:start, starter) do
      assert_raises(MusicMetadata::ProviderError) do
        client.get_json("https://example.org/start")
      end
    end

    assert_match "Refusing insecure redirect", error.message
  end

  private

  ZeroRandom = Struct.new(:unused) do
    def rand
      0
    end
  end

  def build_client(**options)
    MusicMetadata::HttpClient.new(
      user_agent: "Test/1.0 (test@example.com)",
      timeout: 1,
      retry_base_interval: 0,
      **options
    )
  end

  def net_response(type, code, body)
    response = type.new("1.1", code, type.name)
    response.instance_variable_set(:@read, true)
    response.body = body
    response
  end
end
