# frozen_string_literal: true

require "mock_openai"
require "rack/test"
require "tmpdir"
require "fileutils"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Use a temp state file for all specs to avoid polluting tmp/
  config.before(:each) do
    @state_dir = Dir.mktmpdir
    @state_file = File.join(@state_dir, "mock_openai_state.json")
    allow(MockOpenAI).to receive(:config).and_return(
      MockOpenAI::Config.new(state_file: @state_file)
    )
  end

  config.after(:each) do
    FileUtils.rm_rf(@state_dir)
  end
end
