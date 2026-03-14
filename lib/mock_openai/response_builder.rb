# frozen_string_literal: true

require "securerandom"

module MockOpenAI
  class ResponseBuilder
    def self.build(content:, model: "mock-gpt-4")
      {
        "id" => "mock-chatcmpl-#{SecureRandom.hex(8)}",
        "object" => "chat.completion",
        "created" => Time.now.to_i,
        "model" => model,
        "choices" => [
          {
            "index" => 0,
            "message" => {"role" => "assistant", "content" => content},
            "finish_reason" => "stop"
          }
        ],
        "usage" => {"prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0}
      }
    end
  end
end
