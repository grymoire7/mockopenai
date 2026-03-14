# frozen_string_literal: true

require "fileutils"
require "json"

module MockOpenAI
  class State
    EMPTY = {
      "rules" => [],
      "response_template" => nil,
      "default_response" => nil,
      "metadata" => {}
    }.freeze

    def self.state_file
      MockOpenAI.config.state_file
    end

    def self.write(rules:, response_template: nil, default_response: nil)
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, {
        "rules" => rules,
        "response_template" => response_template,
        "default_response" => default_response,
        "metadata" => {}
      }.to_json)
    end

    def self.read
      return EMPTY unless File.exist?(state_file)

      JSON.parse(File.read(state_file))
    rescue JSON::ParserError
      puts "[MockOpenAI] Warning: state file is corrupt, using empty state"
      EMPTY
    end

    def self.reset!
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, EMPTY.to_json)
    end
  end
end
