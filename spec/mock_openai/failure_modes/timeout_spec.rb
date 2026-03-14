# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::Timeout do
  it "returns the :timeout symbol" do
    result = described_class.new.apply(request: {}, response: {})
    expect(result).to eq(:timeout)
  end
end
