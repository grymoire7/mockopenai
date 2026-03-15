# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::Base do
  include Rack::Test::Methods

  # Anonymous subclass avoids top-level constant pollution and collision risk
  # if specs are reorganised. Returns a neutral JSON body so tests can inspect
  # content without caring about OpenAI vs Anthropic envelope format.
  let(:handler_class) do
    Class.new(MockOpenAI::Handlers::Base) do
      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message: body["system"].to_s,
          model: body["model"] || "test-model"
        }
      end

      def build_success_response(content, model)
        [200, {"Content-Type" => "application/json"},
          [{"test_content" => content, "test_model" => model}.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        [599, {"Content-Type" => "application/json"},
          [{"failure_mode_applied" => mode, "model" => request_context[:model]}.to_json]]
      end
    end
  end

  def app
    handler_class.new
  end

  def post_messages(body)
    post "/v1/messages", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  let(:valid_request) do
    {
      "model" => "claude-3",
      "messages" => [{"role" => "user", "content" => "Hello"}]
    }
  end

  context "with no rules in state" do
    it "returns 200" do
      post_messages(valid_request)
      expect(last_response.status).to eq(200)
    end

    it "uses the config default_response as content" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq(MockOpenAI.config.default_response)
    end

    it "passes the model from the request" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_model"]).to eq("claude-3")
    end
  end

  context "content resolution — five-step fallback chain" do
    it "step 1: uses rule response when rule matches" do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "rule response"}])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("rule response")
    end

    it "step 2: renders rule template when rule has template" do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "echo: {{last_user_message}}"}
      ])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("echo: Hello")
    end

    it "step 3: uses state response_template when no rule matches" do
      MockOpenAI::State.write(
        rules: [],
        response_template: "global: {{last_user_message}}"
      )
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("global: Hello")
    end

    it "step 4: uses state default_response when no rule and no response_template" do
      MockOpenAI::State.write(rules: [], default_response: "state default")
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("state default")
    end

    it "step 5: uses config default_response as final fallback" do
      MockOpenAI::State.write(rules: [])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq(MockOpenAI.config.default_response)
    end
  end

  context "failure mode dispatch" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "rate_limit"}])
    end

    it "delegates to apply_failure_mode with the mode string" do
      post_messages(valid_request)
      expect(last_response.status).to eq(599)
      body = JSON.parse(last_response.body)
      expect(body["failure_mode_applied"]).to eq("rate_limit")
    end

    it "passes request_context to apply_failure_mode" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["model"]).to eq("claude-3")
    end
  end

  context "with invalid JSON body" do
    it "returns 400" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
    end

    it "returns an invalid_request_error" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "extract_text_content helper" do
    it "normalizes a content-block array to plain text" do
      request = {
        "model" => "claude-3",
        "messages" => [
          {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
        ]
      }
      MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
      post_messages(request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("matched")
    end

    it "passes a plain string through unchanged" do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "matched plain"}])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("matched plain")
    end
  end

  it "logs the request to stdout" do
    expect { post_messages(valid_request) }.to output(/\[MockOpenAI\]/).to_stdout
  end
end
