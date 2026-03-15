# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class Messages < Base
      private

      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message: body["system"].to_s,
          model: body["model"] || "mock-claude-3"
        }
      end

      def build_success_response(content, model)
        response = AnthropicResponseBuilder.build(content: content, model: model)
        [200, JSON_HEADERS, [response.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        result = FailureModes.apply(mode, request: {}, response: {})
        return handle_symbol_result(result, request_context) if result.is_a?(Symbol)
        result
      end

      def handle_symbol_result(symbol, request_context)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          error_body = {"type" => "error", "error" => {"type" => "overloaded_error", "message" => "Overloaded"}}
          [200, JSON_HEADERS, [error_body.to_json]]
        when :stream_truncated
          chunks = [
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\" world\"}}\n\n"
          ]
          [200, {"Content-Type" => "text/event-stream"}, chunks]
        end
      end
    end
  end
end
