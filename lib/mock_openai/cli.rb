# lib/mock_openai/cli.rb
# frozen_string_literal: true

require "optparse"

module MockOpenAI
  class CLI
    SAMPLE_CONFIG = <<~YAML
      # MockOpenAI configuration
      # port: 4000
      # timeout_seconds: 5
      # default_response: "Mock response from MockOpenAI"
    YAML

    def self.run(argv = ARGV)
      command = argv.first
      case command
      when "start"
        port = 4000
        OptionParser.new do |opts|
          opts.on("--port=PORT", Integer) { |p| port = p }
        end.parse!(argv[1..])
        Server.start(port: port)
      when "init"
        path = config_file_path
        if File.exist?(path)
          puts "mock_openai.yml already exists at #{path}"
        else
          File.write(path, SAMPLE_CONFIG)
          puts "Created #{path}"
        end
      when "check"
        cfg = MockOpenAI.config
        puts "MockOpenAI configuration:"
        puts "  port:             #{cfg.port}"
        puts "  timeout_seconds:  #{cfg.timeout_seconds}"
        puts "  default_response: #{cfg.default_response}"
        puts "  state_file:       #{cfg.state_file}"
      else
        puts "Usage: mock-openai <command> [options]"
        puts ""
        puts "Commands:"
        puts "  start [--port=N]   Start the mock server (default port: 4000)"
        puts "  init               Create a sample mock_openai.yml"
        puts "  check              Show resolved configuration"
        exit(1)
      end
    end

    def self.config_file_path
      "mock_openai.yml"
    end
  end
end
