# lib/mock_openai/minitest.rb
# frozen_string_literal: true

require "mock_openai"

module MockOpenAI
  module Minitest
    def before_setup
      super
      MockOpenAI.reset!
    end

    def after_teardown
      MockOpenAI.reset!
      super
    end
  end
end
