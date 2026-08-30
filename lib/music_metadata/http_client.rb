# frozen_string_literal: true

require "json"
require "net/http"
require "timeout"
require "uri"

module MusicMetadata
  class HttpClient
    REDIRECT_LIMIT = 3

    def initialize(user_agent:, timeout:, limiters: {})
      @user_agent = user_agent
      @timeout = timeout
      @limiters = limiters
    end

    def get_json(url, params: {}, allow_not_found: false)
      uri = URI(url)
      uri.query = URI.encode_www_form(params) unless params.empty?
      response = request(uri)

      return nil if allow_not_found && response.code.to_i == 404
      unless response.is_a?(Net::HTTPSuccess)
        raise HttpError.new(
          "GET #{uri.host} failed with HTTP #{response.code}",
          status: response.code.to_i,
          body: response.body
        )
      end

      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError => error
      raise ProviderError, "#{uri.host} returned invalid JSON: #{error.message}"
    end

    private

    def request(uri, redirects_remaining = REDIRECT_LIMIT)
      @limiters[uri.host]&.wait

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = @user_agent

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout,
        read_timeout: @timeout
      ) { |http| http.request(request) }

      if response.is_a?(Net::HTTPRedirection)
        raise ProviderError, "Too many redirects from #{uri.host}" if redirects_remaining.zero?

        return request(URI.join(uri, response["location"]), redirects_remaining - 1)
      end

      response
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise ProviderError, "GET #{uri.host} failed: #{error.message}"
    end
  end
end
