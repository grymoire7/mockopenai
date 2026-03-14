# spec/integration/rspec_metadata_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "mock_openai/rspec"

# These specs verify end-to-end: metadata tag → state written → correct server behaviour.
# They use the Router directly via rack-test (no running server needed).
RSpec.describe "RSpec metadata integration", :mock_openai do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def post_chat(user_message)
    body = {
      "model" => "gpt-4",
      "messages" => [{"role" => "user", "content" => user_message}]
    }.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
  end

  it "state is empty at the start of a :mock_openai test" do
    expect(MockOpenAI::State.read["rules"]).to eq([])
  end

  context "when rules are set within the test" do
    it "returns the matched response" do
      MockOpenAI.set_responses([{match: "ping", response: "pong"}])
      post_chat("ping")
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("pong")
    end
  end
end

RSpec.describe "shortcut failure mode tags" do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def post_chat
    body = {"model" => "gpt-4", "messages" => [{"role" => "user", "content" => "hi"}]}.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
  end

  it "sets rate_limit failure mode", :mock_openai_rate_limit do
    post_chat
    expect(last_response.status).to eq(429)
  end

  it "sets internal_error failure mode", :mock_openai_internal_error do
    post_chat
    expect(last_response.status).to eq(500)
  end

  it "sets malformed_json failure mode", :mock_openai_malformed_json do
    post_chat
    expect { JSON.parse(last_response.body) }.to raise_error(JSON::ParserError)
  end
end
