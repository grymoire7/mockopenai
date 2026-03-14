# frozen_string_literal: true

require "yaml"

module MockOpenAI
  class Config
    DEFAULTS = {
      "port" => 4000,
      "timeout_seconds" => 5,
      "default_response" => "Mock response from MockOpenAI",
      "state_file" => "tmp/mock_openai_state.json"
    }.freeze

    attr_reader :port, :timeout_seconds, :default_response, :state_file

    def self.load(path = "mock_openai.yml")
      file_config = File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
      merged = DEFAULTS.merge(file_config.transform_keys(&:to_s))
      new(**merged.transform_keys(&:to_sym))
    end

    def initialize(port: DEFAULTS["port"], timeout_seconds: DEFAULTS["timeout_seconds"],
      default_response: DEFAULTS["default_response"], state_file: DEFAULTS["state_file"])
      @port = port
      @timeout_seconds = timeout_seconds
      @default_response = default_response
      @state_file = state_file
    end
  end
end
