# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Config do
  describe ".load" do
    context "when no config file exists" do
      it "returns a Config with defaults" do
        config = MockOpenAI::Config.load("/nonexistent/mock_openai.yml")
        expect(config.port).to eq(4000)
        expect(config.timeout_seconds).to eq(5)
        expect(config.default_response).to eq("Mock response from MockOpenAI")
        expect(config.state_file).to eq("tmp/mock_openai_state.json")
      end
    end

    context "when config file exists" do
      it "merges file values over defaults" do
        yml = Tempfile.new(["mock_openai", ".yml"])
        yml.write("port: 9000\ntimeout_seconds: 10\n")
        yml.flush

        config = MockOpenAI::Config.load(yml.path)
        expect(config.port).to eq(9000)
        expect(config.timeout_seconds).to eq(10)
        expect(config.default_response).to eq("Mock response from MockOpenAI")
      ensure
        yml.close
        yml.unlink
      end
    end
  end

  describe "#initialize" do
    it "accepts keyword arguments to override any field" do
      config = MockOpenAI::Config.new(state_file: "/tmp/custom.json")
      expect(config.state_file).to eq("/tmp/custom.json")
      expect(config.port).to eq(4000)
    end
  end
end
