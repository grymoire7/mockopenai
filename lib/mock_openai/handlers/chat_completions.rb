# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class ChatCompletions < Base
      private

      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        system_msg = messages.find { |m| m["role"] == "system" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message: extract_text_content(system_msg&.dig("content")),
          model: body["model"] || "mock-gpt-4"
        }
      end

      def build_success_response(content, model)
        response = ResponseBuilder.build(content: content, model: model)
        [200, json_headers, [response.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        result = FailureModes.apply(mode, request: {}, response: {})
        return handle_symbol_result(result) if result.is_a?(Symbol)
        result
      end

      def handle_symbol_result(symbol)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          [200, json_headers, [{"choices" => []}.to_json]]
        when :stream_truncated
          chunks = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
          ]
          [200, {"Content-Type" => "text/event-stream"}, chunks]
        end
      end
    end
  end
end
