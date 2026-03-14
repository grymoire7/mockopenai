# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI do
  describe ".set_responses" do
    it "writes rules to the state file" do
      rules = [{match: "Hello", response: "Hi!"}]
      MockOpenAI.set_responses(rules)

      state = MockOpenAI::State.read
      expect(state["rules"].first["match"]).to eq("Hello")
      expect(state["rules"].first["response"]).to eq("Hi!")
    end

    it "converts symbol keys to string keys" do
      MockOpenAI.set_responses([{match: "hi", failure_mode: :timeout}])
      state = MockOpenAI::State.read
      expect(state["rules"].first["failure_mode"]).to eq("timeout")
    end
  end

  describe ".set_failure_mode" do
    it "writes a catch-all rule with the given failure mode" do
      MockOpenAI.set_failure_mode(:rate_limit)
      state = MockOpenAI::State.read
      rule = state["rules"].first
      expect(rule["match"]).to eq(".*")
      expect(rule["failure_mode"]).to eq("rate_limit")
    end
  end

  describe ".reset!" do
    it "clears all rules" do
      MockOpenAI.set_failure_mode(:timeout)
      MockOpenAI.reset!
      expect(MockOpenAI::State.read["rules"]).to eq([])
    end
  end

  describe ".current_failure_mode" do
    it "returns the failure mode from the catch-all rule" do
      MockOpenAI.set_failure_mode(:internal_error)
      expect(MockOpenAI.current_failure_mode).to eq(:internal_error)
    end

    it "returns nil when no catch-all rule exists" do
      MockOpenAI.reset!
      expect(MockOpenAI.current_failure_mode).to be_nil
    end
  end
end
