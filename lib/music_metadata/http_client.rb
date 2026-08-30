# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "digest"
require "time"
require "timeout"
require "uri"

module MusicMetadata
  class HttpClient
    REDIRECT_LIMIT = 3
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
    NETWORK_ERRORS = [Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError].freeze

    def initialize(user_agent:, timeout:, limiters: {}, cache: nil, cache_ttl: 0,
      max_retries: 2, retry_base_interval: 0.25,
      retry_max_interval: 30, sleeper: Kernel.method(:sleep), random: Random.new)
      @user_agent = user_agent
      @timeout = timeout
      @limiters = limiters
      @cache = cache
      @cache_ttl = cache_ttl
      @max_retries = max_retries
      @retry_base_interval = retry_base_interval
      @retry_max_interval = retry_max_interval
      @sleeper = sleeper
      @random = random
    end

    def get_json(url, params: {}, allow_not_found: false)
      uri = URI(url)
      uri.query = URI.encode_www_form(params) unless params.empty?
      request_json(:get, uri, allow_not_found: allow_not_found, cacheable: true)
    end

    def post_form_json(url, params: {}, allow_not_found: false)
      uri = URI(url)
      body = URI.encode_www_form(params)
      request_json(:post, uri, body: body, allow_not_found: allow_not_found)
    end

    private

    def request_json(method, uri, body: nil, allow_not_found: false, cacheable: false)
      cache_key = cache_key(method, uri, body)
      cached = @cache&.read(cache_key) if cacheable
      return cached if cached

      response = request_with_retries(method, uri, body: body)

      return nil if allow_not_found && response.code.to_i == 404
      unless response.code.to_i.between?(200, 299)
        raise HttpError.new(
          "#{method.to_s.upcase} #{uri.host} failed with HTTP #{response.code}",
          status: response.code.to_i,
          body: response.body.to_s.byteslice(0, 1024)
        )
      end

      parsed = deep_freeze(JSON.parse(response.body, symbolize_names: true))
      @cache&.write(cache_key, parsed, ttl: @cache_ttl) if cacheable
      parsed
    rescue JSON::ParserError => error
      raise ProviderError, "#{uri.host} returned invalid JSON: #{error.message}"
    end

    def request_with_retries(method, uri, body: nil)
      attempts = 0

      loop do
        response = request(method, uri, body: body)
        return response unless RETRYABLE_STATUSES.include?(response.code.to_i) && attempts < @max_retries

        wait_before_retry(response, attempts)
        attempts += 1
      rescue *NETWORK_ERRORS => error
        raise ProviderError, "#{method.to_s.upcase} #{uri.host} failed: #{error.message}" if attempts >= @max_retries

        wait_before_retry(nil, attempts)
        attempts += 1
      end
    end

    def request(method, uri, body: nil, redirects_remaining: REDIRECT_LIMIT)
      @limiters[uri.host]&.wait

      net_request = (method == :post) ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      net_request["Accept"] = "application/json"
      net_request["User-Agent"] = @user_agent
      if method == :post
        net_request["Content-Type"] = "application/x-www-form-urlencoded"
        net_request.body = body
      end

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout,
        read_timeout: @timeout
      ) { |http| http.request(net_request) }

      if response.is_a?(Net::HTTPRedirection)
        raise ProviderError, "Too many redirects from #{uri.host}" if redirects_remaining.zero?

        redirected_uri = URI.join(uri, response["location"])
        redirected_method = (response.code.to_i == 303) ? :get : method
        redirected_body = (redirected_method == :get) ? nil : body
        validate_redirect!(uri, redirected_uri, redirected_method)
        return request(
          redirected_method,
          redirected_uri,
          body: redirected_body,
          redirects_remaining: redirects_remaining - 1
        )
      end

      response
    end

    def validate_redirect!(source, destination, method)
      if source.scheme == "https" && destination.scheme != "https"
        raise ProviderError, "Refusing insecure redirect from #{source.host}"
      end

      return unless method == :post && [source.scheme, source.host, source.port] !=
        [destination.scheme, destination.host, destination.port]

      raise ProviderError, "Refusing to forward POST data from #{source.host} to another origin"
    end

    def wait_before_retry(response, attempt)
      retry_after = response && parse_retry_after(response["Retry-After"])
      delay = retry_after || (@retry_base_interval * (2**attempt))
      delay = [delay, @retry_max_interval].min
      delay += @random.rand * [delay * 0.1, 0.1].min if delay.positive?
      @sleeper.call(delay) if delay.positive?
    end

    def parse_retry_after(value)
      return if value.nil? || value.empty?
      return value.to_f if value.match?(/\A\d+(?:\.\d+)?\z/)

      [Time.httpdate(value) - Time.now, 0].max
    rescue ArgumentError
      nil
    end

    def cache_key(method, uri, body)
      Digest::SHA256.hexdigest([method, uri.to_s, body].join("\0"))
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each_value { |item| deep_freeze(item) }.freeze
      when Array
        value.each { |item| deep_freeze(item) }.freeze
      else
        value.freeze
      end
    end
  end
end
