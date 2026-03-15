# frozen_string_literal: true

require "securerandom"

module MockOpenAI
  class AnthropicResponseBuilder
    def self.build(content:, model: "mock-claude-3")
      {
        "id" => "mock-msg-#{SecureRandom.hex(8)}",
        "type" => "message",
        "role" => "assistant",
        "content" => [{"type" => "text", "text" => content}],
        "model" => model,
        "stop_reason" => "end_turn",
        "stop_sequence" => nil,
        "usage" => {"input_tokens" => 0, "output_tokens" => 0}
      }
    end
  end
end
