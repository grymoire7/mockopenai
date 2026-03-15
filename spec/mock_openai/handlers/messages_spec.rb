# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::Messages do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_request) do
    {
      "model" => "claude-3-haiku",
      "system" => "You are helpful.",
      "messages" => [{"role" => "user", "content" => "Hello"}]
    }
  end

  def post_messages(body = valid_request)
    post "/v1/messages", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  context "with no rules in state" do
    it "returns HTTP 200" do
      post_messages
      expect(last_response.status).to eq(200)
    end

    it "returns Anthropic-format response with default content" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq(MockOpenAI.config.default_response)
    end

    it "sets type to 'message'" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body["type"]).to eq("message")
    end

    it "sets stop_reason to 'end_turn'" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body["stop_reason"]).to eq("end_turn")
    end

    it "returns Content-Type application/json" do
      post_messages
      expect(last_response.content_type).to include("application/json")
    end
  end

  context "with a matching rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "Hi there!"}])
    end

    it "returns the matched response in content[0].text" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("Hi there!")
    end
  end

  context "with a template rule" do
    before do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "You said: {{last_user_message}}"}
      ])
    end

    it "renders the template with the user message" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("You said: Hello")
    end

    it "makes the system message available to templates" do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "system: {{system_message}}"}
      ])
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("system: You are helpful.")
    end
  end

  context "with a failure_mode rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "rate_limit"}])
    end

    it "returns 429" do
      post_messages
      expect(last_response.status).to eq(429)
    end
  end

  context "with timeout failure mode" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "timeout"}])
      allow(MockOpenAI.config).to receive(:timeout_seconds).and_return(0)
    end

    it "returns 200 with an Anthropic-format error body" do
      post_messages
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["type"]).to eq("error")
    end
  end

  context "with truncated_stream failure mode" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "truncated_stream"}])
    end

    it "returns text/event-stream content type" do
      post_messages
      expect(last_response.content_type).to include("text/event-stream")
    end

    it "returns Anthropic SSE chunk format" do
      post_messages
      expect(last_response.body).to include("content_block_delta")
    end
  end

  context "when request body is not valid JSON" do
    it "returns HTTP 400" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "with content-block array as user message" do
    it "normalizes to plain text for matching" do
      MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
      request = {
        "model" => "claude-3-haiku",
        "messages" => [
          {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
        ]
      }
      post_messages(request)
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("matched")
    end
  end

  it "logs the request to stdout" do
    expect { post_messages }.to output(/\[MockOpenAI\] POST \/v1\/messages/).to_stdout
  end
end
