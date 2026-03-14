# spec/mock_openai/cli_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::CLI do
  describe ".run" do
    context "start command" do
      it "calls Server.start with default port" do
        expect(MockOpenAI::Server).to receive(:start).with(port: 4000)
        described_class.run(["start"])
      end

      it "calls Server.start with --port override" do
        expect(MockOpenAI::Server).to receive(:start).with(port: 9000)
        described_class.run(["start", "--port=9000"])
      end
    end

    context "init command" do
      it "writes mock_openai.yml if it does not exist" do
        target = File.join(@state_dir, "mock_openai.yml")
        allow(described_class).to receive(:config_file_path).and_return(target)

        described_class.run(["init"])

        expect(File.exist?(target)).to be true
        content = File.read(target)
        expect(content).to include("default_response")
      end

      it "prints an error if mock_openai.yml already exists" do
        target = File.join(@state_dir, "mock_openai.yml")
        File.write(target, "existing")
        allow(described_class).to receive(:config_file_path).and_return(target)

        expect do
          described_class.run(["init"])
        end.to output(/already exists/).to_stdout
      end
    end

    context "check command" do
      it "prints resolved config values" do
        expect do
          described_class.run(["check"])
        end.to output(/port.*4000/).to_stdout
      end
    end

    context "unknown command" do
      it "prints usage and exits non-zero" do
        expect do
          expect { described_class.run(["unknown"]) }.to raise_error(SystemExit)
        end.to output(/Usage/).to_stdout
      end
    end
  end
end
