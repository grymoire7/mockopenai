# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class Base
      JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

      def call(env)
        request = Rack::Request.new(env)
        parsed = parse_json_body(request.body.read)
        return error_response(400, "invalid_request_error", "Request body must be valid JSON") unless parsed

        request_context = parse_request(parsed)
        state = State.read
        rule = Matcher.match(state["rules"] || [], request_context[:last_user_message].to_s)

        result = resolve_content(rule, state, request_context)
        log_request(env, rule ? (state["rules"] || []).index(rule) : nil, rule&.dig("failure_mode"))
        result
      end

      private

      # Template methods — subclasses must implement all three

      def parse_request(body)
        raise NotImplementedError, "#{self.class} must implement #parse_request"
      end

      def build_success_response(content, model)
        raise NotImplementedError, "#{self.class} must implement #build_success_response"
      end

      def apply_failure_mode(mode, request_context)
        raise NotImplementedError, "#{self.class} must implement #apply_failure_mode"
      end

      protected

      def extract_text_content(content)
        if content.is_a?(Array)
          content.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
        else
          content.to_s
        end
      end

      private

      def resolve_content(rule, state, request_context)
        model = request_context[:model]

        if rule
          if rule["failure_mode"]
            return apply_failure_mode(rule["failure_mode"], request_context)
          elsif rule["response"]
            return build_success_response(rule["response"], model)
          elsif rule["template"]
            return build_success_response(
              TemplateRenderer.render(rule["template"], request_context), model
            )
          end
        end

        if state["response_template"]
          return build_success_response(
            TemplateRenderer.render(state["response_template"], request_context), model
          )
        end

        fallback = state["default_response"] || MockOpenAI.config.default_response
        build_success_response(fallback, model)
      end

      def parse_json_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        nil
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
