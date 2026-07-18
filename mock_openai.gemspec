# frozen_string_literal: true

require_relative "lib/mock_openai/version"

Gem::Specification.new do |spec|
  spec.name = "mock_openai"
  spec.version = MockOpenAI::VERSION
  spec.authors = ["Tracy Atteberry"]
  spec.summary = "A local mock server for OpenAI-compatible APIs"
  spec.description = "Drop-in mock server for testing Rails apps that use OpenAI-compatible APIs. Provides deterministic responses and per-request failure simulation."
  spec.license = "MIT"
  spec.homepage = "https://github.com/grymoire7/mockopenai"

  spec.metadata = {
    "documentation_uri" => "https://grymoire7.github.io/mockopenai",
    "homepage_uri"      => "https://github.com/grymoire7/mockopenai"
  }

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["mock-openai"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "rackup", "~> 2.0"
  spec.add_dependency "logger", "~> 1.0"
  spec.add_dependency "webrick", "~> 1.8"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rack-test", "~> 2.0"
  spec.add_development_dependency "standard", "~> 1.0"
end
