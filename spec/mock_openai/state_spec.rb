# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::State do
  subject(:state) { described_class }

  describe ".write and .read" do
    it "persists rules to the state file and reads them back" do
      rules = [{"match" => "Hello", "response" => "Hi!"}]
      state.write(rules: rules)
      result = state.read
      expect(result["rules"]).to eq(rules)
    end

    it "persists response_template and default_response" do
      state.write(rules: [], response_template: "Reply: {{last_user_message}}", default_response: "fallback")
      result = state.read
      expect(result["response_template"]).to eq("Reply: {{last_user_message}}")
      expect(result["default_response"]).to eq("fallback")
    end
  end

  describe ".reset!" do
    it "overwrites state with empty rules" do
      state.write(rules: [{"match" => ".*", "failure_mode" => "timeout"}])
      state.reset!
      result = state.read
      expect(result["rules"]).to eq([])
      expect(result["response_template"]).to be_nil
      expect(result["default_response"]).to be_nil
    end
  end

  describe ".read" do
    context "when state file does not exist" do
      it "returns EMPTY without raising" do
        result = state.read
        expect(result).to eq(MockOpenAI::State::EMPTY)
      end
    end

    context "when state file contains invalid JSON" do
      it "logs a warning and returns EMPTY" do
        File.write(MockOpenAI.config.state_file, "{ bad json ]]]")
        expect { state.read }.to output(/\[MockOpenAI\].*corrupt/).to_stdout
        expect(state.read).to eq(MockOpenAI::State::EMPTY)
      end
    end
  end
end
