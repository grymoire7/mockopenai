# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::InternalError do
  subject(:result) { described_class.new.apply(request: {}, response: {}) }

  it "returns HTTP 500" do
    expect(result[0]).to eq(500)
  end

  it "returns a server_error body" do
    body = JSON.parse(result[2].first)
    expect(body.dig("error", "type")).to eq("server_error")
  end
end
