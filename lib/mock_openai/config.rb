# frozen_string_literal: true

module MockOpenAI
  class Config
    attr_reader :state_file

    def initialize(state_file: nil)
      @state_file = state_file || File.join(Dir.tmpdir, "mock_openai_state.json")
    end

    def self.load
      new
    end
  end
end
