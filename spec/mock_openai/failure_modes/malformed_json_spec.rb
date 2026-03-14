# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::MalformedJson do
  subject(:result) { described_class.new.apply(request: {}, response: {}) }

  it "returns HTTP 200" do
    expect(result[0]).to eq(200)
  end

  it "returns a body that is not valid JSON" do
    expect { JSON.parse(result[2].first) }.to raise_error(JSON::ParserError)
  end
end
