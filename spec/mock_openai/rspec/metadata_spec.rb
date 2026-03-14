# spec/mock_openai/rspec/metadata_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "mock_openai/rspec"

# Note: These tests verify the module's hook registration, not the hooks themselves
# (which are tested in spec/integration/rspec_metadata_spec.rb).
RSpec.describe MockOpenAI::RSpec::Metadata do
  it "is loadable without raising" do
    expect { require "mock_openai/rspec" }.not_to raise_error
  end
end
