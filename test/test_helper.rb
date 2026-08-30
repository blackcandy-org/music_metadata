# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
  minimum_coverage 90
end

require "minitest/autorun"
require "music_metadata"

class FakeHttp
  attr_reader :requests

  def initialize(responses = {})
    @responses = responses
    @requests = []
  end

  def get_json(url, params: {}, allow_not_found: false)
    respond(:get, url, params, allow_not_found)
  end

  def post_form_json(url, params: {}, allow_not_found: false)
    respond(:post, url, params, allow_not_found)
  end

  private

  def respond(method, url, params, allow_not_found)
    @requests << {method: method, url: url, params: params, allow_not_found: allow_not_found}
    response = @responses.fetch(url)
    response.respond_to?(:call) ? response.call(params) : response
  end
end
