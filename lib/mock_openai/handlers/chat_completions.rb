# lib/mock_openai/handlers/chat_completions.rb
# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class ChatCompletions
      JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

      def call(env)
        request = Rack::Request.new(env)
        parsed = parse_body(request.body.read)
        return error_response(400, "invalid_request_error", "Request body must be valid JSON") unless parsed

        state = State.read
        last_user_message = extract_last_user_message(parsed)
        model = parsed["model"] || "mock-gpt-4"
        system_message = parsed["messages"]&.find { |m| m["role"] == "system" }&.dig("content")

        rule = Matcher.match(state["rules"] || [], last_user_message.to_s)

        result = resolve_rule(rule, state, last_user_message, system_message, model)
        log_request(env, rule ? (state["rules"] || []).index(rule) : nil, rule&.dig("failure_mode"))
        result
      end

      private

      def parse_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def extract_last_user_message(parsed)
        messages = parsed["messages"] || []
        messages.reverse.find { |m| m["role"] == "user" }&.dig("content")
      end

      def resolve_rule(rule, state, last_user_message, system_message, model)
        context = {last_user_message: last_user_message, system_message: system_message, model: model}

        if rule
          if rule["failure_mode"]
            result = FailureModes.apply(rule["failure_mode"], request: {}, response: {})
            return handle_symbol_result(result) if result.is_a?(Symbol)
            return result
          elsif rule["response"]
            return success_response(rule["response"], model)
          elsif rule["template"]
            return success_response(TemplateRenderer.render(rule["template"], context), model)
          end
        end

        # No rule matched — use global fallback
        if state["response_template"]
          return success_response(TemplateRenderer.render(state["response_template"], context), model)
        end

        fallback = state["default_response"] || MockOpenAI.config.default_response
        success_response(fallback, model)
      end

      def handle_symbol_result(symbol)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          [200, JSON_HEADERS, [{"choices" => []}.to_json]]
        when :stream_truncated
          truncated_sse_response
        end
      end

      def truncated_sse_response
        chunks = [
          "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
          "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
        ]
        [200, {"Content-Type" => "text/event-stream"}, chunks]
      end

      def success_response(content, model)
        response = ResponseBuilder.build(content: content, model: model)
        [200, JSON_HEADERS, [response.to_json]]
      end

      def error_response(status, type, message)
        body = {"error" => {"type" => type, "message" => message}}
        [status, JSON_HEADERS, [body.to_json]]
      end

      def log_request(env, rule_index, failure_mode)
        method = env["REQUEST_METHOD"]
        path = env["PATH_INFO"]
        rule_label = rule_index.nil? ? "none" : rule_index.to_s
        mode_label = failure_mode.nil? ? "none" : failure_mode.to_s
        puts "[MockOpenAI] #{method} #{path} | rule=#{rule_label} | mode=#{mode_label}"
      end
    end
  end
end
