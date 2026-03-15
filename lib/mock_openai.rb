# frozen_string_literal: true

require "json"
require_relative "mock_openai/version"
require_relative "mock_openai/config"
require_relative "mock_openai/state"
require_relative "mock_openai/matcher"
require_relative "mock_openai/response_builder"
require_relative "mock_openai/anthropic_response_builder"
require_relative "mock_openai/template_renderer"
require_relative "mock_openai/failure_modes/base"
require_relative "mock_openai/failure_modes/timeout"
require_relative "mock_openai/failure_modes/rate_limit"
require_relative "mock_openai/failure_modes/malformed_json"
require_relative "mock_openai/failure_modes/internal_error"
require_relative "mock_openai/failure_modes/truncated_stream"
require_relative "mock_openai/handlers/base"
require_relative "mock_openai/handlers/chat_completions"
require_relative "mock_openai/router"
require_relative "mock_openai/server"
require_relative "mock_openai/cli"

module MockOpenAI
  class << self
    def config
      @config ||= Config.load
    end

    def set_responses(rules)
      State.write(rules: rules.map { |r| r.transform_keys(&:to_s) })
    end

    def set_failure_mode(mode)
      set_responses([{"match" => ".*", "failure_mode" => mode.to_s}])
    end

    def reset!
      State.reset!
    end

    def current_failure_mode
      state = State.read
      catch_all = state["rules"].find { |r| r["match"] == ".*" && r["failure_mode"] }
      catch_all&.dig("failure_mode")&.to_sym
    end
  end
end
