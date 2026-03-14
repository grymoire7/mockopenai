# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::TruncatedStream do
  it "returns the :stream_truncated symbol" do
    result = described_class.new.apply(request: {}, response: {})
    expect(result).to eq(:stream_truncated)
  end
end
