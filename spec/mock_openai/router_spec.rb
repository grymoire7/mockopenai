# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Router do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_body) do
    {"model" => "gpt-4", "messages" => [{"role" => "user", "content" => "hi"}]}.to_json
  end

  it "routes POST /v1/chat/completions to ChatCompletions handler" do
    post "/v1/chat/completions", valid_body, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body["object"]).to eq("chat.completion")
  end

  it "returns 404 for unknown routes" do
    get "/unknown"
    expect(last_response.status).to eq(404)
    body = JSON.parse(last_response.body)
    expect(body.dig("error", "type")).to eq("invalid_request_error")
  end

  it "returns 404 for wrong method on a known path" do
    get "/v1/chat/completions"
    expect(last_response.status).to eq(404)
  end
end
