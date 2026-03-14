# frozen_string_literal: true

# Standalone spec that demonstrates the RSpec metadata integration.
# Run with: bundle exec rspec docs/demo_rspec_spec.rb --format documentation

require_relative "../spec/spec_helper"
require "mock_openai/rspec"

RSpec.describe "MockOpenAI RSpec integration demo" do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def chat(message)
    body = {"model" => "gpt-4", "messages" => [{"role" => "user", "content" => message}]}.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  # :mock_openai tag resets state before the test
  describe "deterministic responses", :mock_openai do
    before do
      MockOpenAI.set_responses([
        {match: "ping", response: "pong"},
        {match: ".*", response: "default answer"}
      ])
    end

    it "matches exact patterns" do
      expect(chat("ping").dig("choices", 0, "message", "content")).to eq("pong")
    end

    it "falls back to catch-all" do
      expect(chat("anything").dig("choices", 0, "message", "content")).to eq("default answer")
    end
  end

  describe "state isolation between examples", :mock_openai do
    it "starts with no rules (state was reset by :mock_openai before hook)" do
      expect(MockOpenAI::State.read["rules"]).to eq([])
    end
  end

  # Shortcut tags set a failure mode automatically
  it "simulates rate limiting", :mock_openai_rate_limit do
    post "/v1/chat/completions",
      '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}',
      "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(429)
    expect(JSON.parse(last_response.body).dig("error", "type")).to eq("rate_limit_error")
  end

  it "simulates server errors", :mock_openai_internal_error do
    post "/v1/chat/completions",
      '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}',
      "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(500)
  end
end
