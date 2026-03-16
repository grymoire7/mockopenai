# frozen_string_literal: true

require "fileutils"
require "logger"
require "socket"

module MockOpenAI
  class Server
    def self.start(port: MockOpenAI.config.port)
      state_file = MockOpenAI.config.state_file
      FileUtils.mkdir_p(File.dirname(state_file))
      State.reset! unless File.exist?(state_file)

      puts "MockOpenAI v#{VERSION} started"
      puts "  Listening on: http://localhost:#{port}"
      puts "  State file:   #{state_file}"

      config_status = File.exist?("mock_openai.yml") ? "mock_openai.yml" : "mock_openai.yml (not found, using defaults)"
      puts "  Config:       #{config_status}"

      run_rack_server(port: port)
    end

    def self.run_rack_server(port: MockOpenAI.config.port)
      require "rackup"
      Rackup::Server.start(
        app: Router.new,
        Port: port,
        Host: "127.0.0.1",
        server: :webrick,
        Logger: Logger.new($stdout),
        AccessLog: []
      )
    end

    def self.wait_until_ready(timeout: 5)
      deadline = Time.now + timeout
      loop do
        TCPSocket.new("127.0.0.1", MockOpenAI.config.port).close
        return
      rescue Errno::ECONNREFUSED
        raise "MockOpenAI server did not start within #{timeout}s" if Time.now > deadline
        sleep 0.05
      end
    end
  end
end
