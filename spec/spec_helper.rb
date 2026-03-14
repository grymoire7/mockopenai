# frozen_string_literal: true

require "mock_openai"
require "rack/test"
require "tmpdir"
require "fileutils"
require "tempfile"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Suppress stdout during tests; output(...).to_stdout still captures correctly
  # because that matcher replaces $stdout itself with its own StringIO.
  config.around(:each) do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
  ensure
    $stdout = original_stdout
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
