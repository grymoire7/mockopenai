# lib/mock_openai/rspec/metadata.rb
# frozen_string_literal: true

module MockOpenAI
  module RSpec
    module Metadata
      FAILURE_MODE_TAGS = {
        mock_openai_timeout: :timeout,
        mock_openai_rate_limit: :rate_limit,
        mock_openai_malformed_json: :malformed_json,
        mock_openai_internal_error: :internal_error,
        mock_openai_truncated_stream: :truncated_stream
      }.freeze
    end
  end
end

::RSpec.configure do |config|
  # Generic tag: reset state before test
  config.before(:each, :mock_openai) do
    MockOpenAI.reset!
  end

  # Shortcut failure mode tags: reset then set mode
  MockOpenAI::RSpec::Metadata::FAILURE_MODE_TAGS.each do |tag, mode|
    config.before(:each, tag) do
      MockOpenAI.reset!
      MockOpenAI.set_failure_mode(mode)
    end
  end

  # Reset after any mock_openai-tagged test
  config.after(:each) do |example|
    if example.metadata.keys.any? { |k| k.to_s.start_with?("mock_openai") }
      MockOpenAI.reset!
    end
  end
end
