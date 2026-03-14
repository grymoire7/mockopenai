# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::RateLimit do
  subject(:result) { described_class.new.apply(request: {}, response: {}) }

  it "returns HTTP 429" do
    expect(result[0]).to eq(429)
  end

  it "returns JSON content type" do
    expect(result[1]["Content-Type"]).to eq("application/json")
  end

  it "returns a rate_limit_error body" do
    body = JSON.parse(result[2].first)
    expect(body.dig("error", "type")).to eq("rate_limit_error")
    expect(body.dig("error", "code")).to eq("rate_limit_exceeded")
  end
end
