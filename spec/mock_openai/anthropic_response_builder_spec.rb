# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::AnthropicResponseBuilder do
  describe ".build" do
    subject(:response) { described_class.build(content: "Hello!", model: "mock-claude-3") }

    it "returns type 'message'" do
      expect(response["type"]).to eq("message")
    end

    it "sets role to 'assistant'" do
      expect(response["role"]).to eq("assistant")
    end

    it "places content in content[0].text" do
      expect(response.dig("content", 0, "text")).to eq("Hello!")
    end

    it "sets content[0].type to 'text'" do
      expect(response.dig("content", 0, "type")).to eq("text")
    end

    it "sets stop_reason to 'end_turn'" do
      expect(response["stop_reason"]).to eq("end_turn")
    end

    it "includes a mock-msg- prefixed id" do
      expect(response["id"]).to match(/\Amock-msg-/)
    end

    it "includes the model name" do
      expect(response["model"]).to eq("mock-claude-3")
    end

    it "includes usage with input_tokens and output_tokens" do
      expect(response["usage"]).to eq("input_tokens" => 0, "output_tokens" => 0)
    end

    it "generates unique ids on each call" do
      r1 = described_class.build(content: "a")
      r2 = described_class.build(content: "b")
      expect(r1["id"]).not_to eq(r2["id"])
    end

    it "uses mock-claude-3 as the default model" do
      r = described_class.build(content: "x")
      expect(r["model"]).to eq("mock-claude-3")
    end
  end
end
