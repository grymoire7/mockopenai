# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Server do
  describe ".start" do
    it "creates the tmp directory if it does not exist" do
      dir = File.dirname(MockOpenAI.config.state_file)
      FileUtils.rm_rf(dir)

      allow(described_class).to receive(:run_rack_server)
      described_class.start

      expect(Dir.exist?(dir)).to be true
    end

    it "initialises the state file if it does not exist" do
      allow(described_class).to receive(:run_rack_server)
      FileUtils.rm_f(MockOpenAI.config.state_file)

      described_class.start

      state = JSON.parse(File.read(MockOpenAI.config.state_file))
      expect(state["rules"]).to eq([])
    end

    it "does not overwrite an existing state file" do
      existing = {"rules" => [{"match" => "hi", "response" => "hello"}], "metadata" => {}}
      FileUtils.mkdir_p(File.dirname(MockOpenAI.config.state_file))
      File.write(MockOpenAI.config.state_file, existing.to_json)

      allow(described_class).to receive(:run_rack_server)
      described_class.start

      state = JSON.parse(File.read(MockOpenAI.config.state_file))
      expect(state["rules"].first["match"]).to eq("hi")
    end

    it "prints startup information" do
      allow(described_class).to receive(:run_rack_server)
      expect do
        described_class.start(port: 4001)
      end.to output(/localhost:4001/).to_stdout
    end
  end
end
