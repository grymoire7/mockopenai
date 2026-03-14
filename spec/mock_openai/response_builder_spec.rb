# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::ResponseBuilder do
  describe ".build" do
    subject(:response) { described_class.build(content: "Hello!", model: "mock-gpt-4") }

    it "returns a hash with the correct object type" do
      expect(response["object"]).to eq("chat.completion")
    end

    it "includes the content in choices[0].message.content" do
      expect(response.dig("choices", 0, "message", "content")).to eq("Hello!")
    end

    it "sets finish_reason to stop" do
      expect(response.dig("choices", 0, "finish_reason")).to eq("stop")
    end

    it "includes a mock id" do
      expect(response["id"]).to match(/\Amock-chatcmpl-/)
    end

    it "includes the model name" do
      expect(response["model"]).to eq("mock-gpt-4")
    end

    it "includes usage fields zeroed out" do
      expect(response["usage"]).to eq(
        "prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0
      )
    end

    it "includes a created timestamp" do
      expect(response["created"]).to be_a(Integer)
    end
  end
end
