# frozen_string_literal: true

require "minitest/autorun"
require "music_metadata"

class FakeHttp
  attr_reader :requests

  def initialize(responses = {})
    @responses = responses
    @requests = []
  end

  def get_json(url, params: {}, allow_not_found: false)
    @requests << { url: url, params: params, allow_not_found: allow_not_found }
    response = @responses.fetch(url)
    response.respond_to?(:call) ? response.call(params) : response
  end
end
