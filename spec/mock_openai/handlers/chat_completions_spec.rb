# spec/mock_openai/handlers/chat_completions_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::ChatCompletions do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_request) do
    {
      "model" => "gpt-4",
      "messages" => [
        {"role" => "system", "content" => "You are helpful."},
        {"role" => "user", "content" => "Hello"}
      ]
    }
  end

  def post_chat(body = valid_request)
    post "/v1/chat/completions", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  context "with no rules in state" do
    it "returns HTTP 200" do
      post_chat
      expect(last_response.status).to eq(200)
    end

    it "returns JSON with the default response in choices[0]" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq(MockOpenAI.config.default_response)
    end

    it "returns Content-Type application/json" do
      post_chat
      expect(last_response.content_type).to include("application/json")
    end
  end

  context "with a matching rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "Hi there!"}])
    end

    it "returns the matched response" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("Hi there!")
    end
  end

  context "with a content-block array as user message (vision format)" do
    before do
      MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
    end

    it "normalizes the content-block array to plain text for rule matching" do
      body = {
        "model" => "gpt-4",
        "messages" => [
          {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
        ]
      }
      post "/v1/chat/completions", body.to_json, "CONTENT_TYPE" => "application/json"
      response_body = JSON.parse(last_response.body)
      expect(response_body.dig("choices", 0, "message", "content")).to eq("matched")
    end
  end

  context "with a template rule" do
    before do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "You said: {{last_user_message}}"}
      ])
    end

    it "renders the template with the user message" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("You said: Hello")
    end
  end

  context "with a failure_mode rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "rate_limit"}])
    end

    it "returns 429" do
      post_chat
      expect(last_response.status).to eq(429)
    end
  end

  context "when request body is not valid JSON" do
    it "returns HTTP 400" do
      post "/v1/chat/completions", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "with multiple rules" do
    before do
      MockOpenAI::State.write(rules: [
        {"match" => "Hello", "response" => "Hi!"},
        {"match" => ".*", "response" => "fallback"}
      ])
    end

    it "matches the first applicable rule" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("Hi!")
    end
  end

  it "logs the request to stdout" do
    expect do
      post_chat
    end.to output(/\[MockOpenAI\] POST \/v1\/chat\/completions/).to_stdout
  end
end
