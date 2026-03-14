# MockOpenAI MVP Implementation Plan

**For agentic workers:** REQUIRED: Use
superpowers:subagent-driven-development (if subagents available) or
superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, Rails-native mock server gem for OpenAI-compatible
APIs that provides deterministic responses and per-request failure simulation
via a unified RSpec metadata API.

**Architecture:** A Rack HTTP server reads a shared JSON state file on every
request; tests write rules to that file via `MockOpenAI.set_responses`. The
server is fully stateless — all per-test behaviour is encoded in the file.
Communication between the test process and server process uses file I/O only;
no client wrapping, no monkey-patching.

**Tech Stack:** Ruby 3.4.5, Rack 3, rackup 2 (WEBrick runner), RSpec 3, rack-test 2, StandardRB

---

## File Map

```
bin/
  mock-openai                        # CLI entrypoint (executable)
lib/
  mock_openai.rb                     # Top-level module, public API, requires
  mock_openai/
    version.rb                       # VERSION constant
    config.rb                        # Config class — loads mock_openai.yml, provides defaults
    state.rb                         # State class — reads/writes tmp/mock_openai_state.json
    matcher.rb                       # Matcher class — stateless rule-matching algorithm
    response_builder.rb              # ResponseBuilder — builds OpenAI-shaped success response hashes
    template_renderer.rb             # TemplateRenderer — substitutes {{variables}} in templates
    failure_modes/
      base.rb                        # FailureModes::Base — interface
      timeout.rb                     # Returns :timeout symbol
      rate_limit.rb                  # Returns [429, headers, body]
      malformed_json.rb              # Returns [200, headers, broken JSON]
      internal_error.rb              # Returns [500, headers, body]
      truncated_stream.rb            # Returns :stream_truncated symbol
    handlers/
      chat_completions.rb            # Rack handler for POST /v1/chat/completions
    router.rb                        # Rack app — routes requests to handlers, 404 otherwise
    server.rb                        # Server.start — boots Rackup with WEBrick
    cli.rb                           # CLI class — parses argv, dispatches commands
    rspec/
      metadata.rb                    # RSpec.configure hooks (require "mock_openai/rspec")
mock_openai.gemspec
Gemfile
spec/
  spec_helper.rb
  mock_openai/
    config_spec.rb
    state_spec.rb
    matcher_spec.rb
    response_builder_spec.rb
    template_renderer_spec.rb
    failure_modes/
      timeout_spec.rb
      rate_limit_spec.rb
      malformed_json_spec.rb
      internal_error_spec.rb
      truncated_stream_spec.rb
    handlers/
      chat_completions_spec.rb
    router_spec.rb
    server_spec.rb
    cli_spec.rb
    rspec/
      metadata_spec.rb
  integration/
    rspec_metadata_spec.rb           # End-to-end: metadata tag → state write → server response
```

---

## Chunk 1: Gem Scaffold + Config + State

### Task 1: Gem Scaffold

**Files:**
- Create: `mock_openai.gemspec`
- Create: `Gemfile`
- Create: `lib/mock_openai/version.rb`
- Create: `lib/mock_openai.rb`
- Create: `spec/spec_helper.rb`

- [ ] **Step 1: Create `lib/mock_openai/version.rb`**

```ruby
# frozen_string_literal: true

module MockOpenAI
  VERSION = "0.1.0"
end
```

- [ ] **Step 2: Create `mock_openai.gemspec`**

```ruby
# frozen_string_literal: true

require_relative "lib/mock_openai/version"

Gem::Specification.new do |spec|
  spec.name = "mock_openai"
  spec.version = MockOpenAI::VERSION
  spec.authors = ["Tracy"]
  spec.summary = "A local mock server for OpenAI-compatible APIs"
  spec.description = "Drop-in mock server for testing Rails apps that use OpenAI-compatible APIs. Provides deterministic responses and per-request failure simulation."
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["mock-openai"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "rackup", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rack-test", "~> 2.0"
  spec.add_development_dependency "standard", "~> 1.0"
end
```

- [ ] **Step 3: Create `Gemfile`**

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rspec"
  gem "rack-test"
end
```

- [ ] **Step 4: Create `lib/mock_openai.rb`** (skeleton — filled in Task 11)

```ruby
# frozen_string_literal: true

require "json"
require_relative "mock_openai/version"
require_relative "mock_openai/config"
require_relative "mock_openai/state"
require_relative "mock_openai/matcher"
require_relative "mock_openai/response_builder"
require_relative "mock_openai/template_renderer"
require_relative "mock_openai/failure_modes/base"
require_relative "mock_openai/failure_modes/timeout"
require_relative "mock_openai/failure_modes/rate_limit"
require_relative "mock_openai/failure_modes/malformed_json"
require_relative "mock_openai/failure_modes/internal_error"
require_relative "mock_openai/failure_modes/truncated_stream"
require_relative "mock_openai/handlers/chat_completions"
require_relative "mock_openai/router"
require_relative "mock_openai/server"
require_relative "mock_openai/cli"

module MockOpenAI
  class << self
    def config
      @config ||= Config.load
    end

    def set_responses(rules)
      State.write(rules: rules.map { |r| r.transform_keys(&:to_s) })
    end

    def set_failure_mode(mode)
      set_responses([{ "match" => ".*", "failure_mode" => mode.to_s }])
    end

    def reset!
      State.reset!
    end

    def current_failure_mode
      state = State.read
      catch_all = state["rules"].find { |r| r["match"] == ".*" && r["failure_mode"] }
      catch_all&.dig("failure_mode")&.to_sym
    end
  end
end
```

- [ ] **Step 5: Create `spec/spec_helper.rb`**

```ruby
# frozen_string_literal: true

require "mock_openai"
require "rack/test"
require "tmpdir"
require "fileutils"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Use a temp state file for all specs to avoid polluting tmp/
  config.before(:each) do
    @state_dir = Dir.mktmpdir
    @state_file = File.join(@state_dir, "mock_openai_state.json")
    allow(MockOpenAI).to receive(:config).and_return(
      MockOpenAI::Config.new(state_file: @state_file)
    )
  end

  config.after(:each) do
    FileUtils.rm_rf(@state_dir)
  end
end
```

- [ ] **Step 6: Run `bundle install`**

```bash
cd /Users/tracy/projects/mockopenai && bundle install
```

Expected: Bundle resolves and installs `rack`, `rackup`, `rspec`, `rack-test`, `standard`.

- [ ] **Step 7: Verify RSpec can run**

```bash
bundle exec rspec --version
```

Expected: prints RSpec version (3.x.x)

- [ ] **Step 8: Commit**

```bash
git add mock_openai.gemspec Gemfile lib/ spec/spec_helper.rb
git commit -m "chore: scaffold gem structure"
```

---

### Task 2: Config

**Files:**
- Create: `lib/mock_openai/config.rb`
- Create: `spec/mock_openai/config_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/config_spec.rb
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/config_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::Config`

- [ ] **Step 3: Implement `Config`**

```ruby
# lib/mock_openai/config.rb
# frozen_string_literal: true

require "yaml"

module MockOpenAI
  class Config
    DEFAULTS = {
      "port" => 4000,
      "timeout_seconds" => 5,
      "default_response" => "Mock response from MockOpenAI",
      "state_file" => "tmp/mock_openai_state.json"
    }.freeze

    attr_reader :port, :timeout_seconds, :default_response, :state_file

    def self.load(path = "mock_openai.yml")
      file_config = File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
      merged = DEFAULTS.merge(file_config.transform_keys(&:to_s))
      new(**merged.transform_keys(&:to_sym))
    end

    def initialize(port: DEFAULTS["port"], timeout_seconds: DEFAULTS["timeout_seconds"],
      default_response: DEFAULTS["default_response"], state_file: DEFAULTS["state_file"])
      @port = port
      @timeout_seconds = timeout_seconds
      @default_response = default_response
      @state_file = state_file
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/config_spec.rb
```

Expected: 3 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/config.rb spec/mock_openai/config_spec.rb
git commit -m "feat: add Config class"
```

---

### Task 3: State

**Files:**
- Create: `lib/mock_openai/state.rb`
- Create: `spec/mock_openai/state_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/state_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::State do
  subject(:state) { described_class }

  describe ".write and .read" do
    it "persists rules to the state file and reads them back" do
      rules = [{ "match" => "Hello", "response" => "Hi!" }]
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
      state.write(rules: [{ "match" => ".*", "failure_mode" => "timeout" }])
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/state_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::State`

- [ ] **Step 3: Implement `State`**

```ruby
# lib/mock_openai/state.rb
# frozen_string_literal: true

module MockOpenAI
  class State
    EMPTY = {
      "rules" => [],
      "response_template" => nil,
      "default_response" => nil,
      "metadata" => {}
    }.freeze

    def self.state_file
      MockOpenAI.config.state_file
    end

    def self.write(rules:, response_template: nil, default_response: nil)
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, {
        "rules" => rules,
        "response_template" => response_template,
        "default_response" => default_response,
        "metadata" => {}
      }.to_json)
    end

    def self.read
      return EMPTY unless File.exist?(state_file)

      JSON.parse(File.read(state_file))
    rescue JSON::ParserError
      puts "[MockOpenAI] Warning: state file is corrupt, using empty state"
      EMPTY
    end

    def self.reset!
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, EMPTY.to_json)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/state_spec.rb
```

Expected: 5 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/state.rb spec/mock_openai/state_spec.rb
git commit -m "feat: add State class"
```

---

## Chunk 2: Matcher + ResponseBuilder + TemplateRenderer

### Task 4: Matcher

**Files:**
- Create: `lib/mock_openai/matcher.rb`
- Create: `spec/mock_openai/matcher_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/matcher_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Matcher do
  let(:rules) do
    [
      { "match" => "Hello", "response" => "Hi!" },
      { "match" => "^Order.*", "response" => "Order shipped." },
      { "match" => "thank", "response" => "You're welcome!" },
      { "match" => ".*", "failure_mode" => "timeout" }
    ]
  end

  describe ".match" do
    it "returns the first rule with an exact match" do
      expect(described_class.match(rules, "Hello")).to eq(rules[0])
    end

    it "returns a rule that regex-matches (anchored start)" do
      expect(described_class.match(rules, "Order status?")).to eq(rules[1])
    end

    it "returns a rule that substring-matches" do
      expect(described_class.match(rules, "Many thanks!")).to eq(rules[2])
    end

    it "returns the catch-all rule when no specific match" do
      expect(described_class.match(rules, "something unrelated")).to eq(rules[3])
    end

    it "returns nil when no rules are defined" do
      expect(described_class.match([], "Hello")).to be_nil
    end

    it "exact match takes precedence over substring match" do
      rules_local = [
        { "match" => "Hello world", "response" => "exact" },
        { "match" => "Hello", "response" => "substring" }
      ]
      expect(described_class.match(rules_local, "Hello world")).to eq(rules_local[0])
    end

    context "when a rule has a malformed regex" do
      it "falls back to substring matching and logs a warning" do
        bad_rules = [{ "match" => "^[unclosed", "response" => "ok" }]
        expect do
          result = described_class.match(bad_rules, "^[unclosed")
          expect(result).to eq(bad_rules[0])
        end.to output(/\[MockOpenAI\].*regex/).to_stdout
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/matcher_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::Matcher`

- [ ] **Step 3: Implement `Matcher`**

```ruby
# lib/mock_openai/matcher.rb
# frozen_string_literal: true

module MockOpenAI
  class Matcher
    def self.match(rules, last_user_message)
      rules.each do |rule|
        return rule if matches?(rule["match"], last_user_message)
      end
      nil
    end

    def self.matches?(pattern, text)
      return false if pattern.nil?

      # 1. Exact match
      return true if pattern == text

      # 2. Regex match (if the pattern looks like a regex)
      if regex_like?(pattern)
        begin
          return true if Regexp.new(pattern).match?(text)
        rescue RegexpError
          puts "[MockOpenAI] Warning: invalid regex '#{pattern}', falling back to substring match"
        end
      end

      # 3. Substring match
      text.include?(pattern)
    end

    def self.regex_like?(pattern)
      pattern.start_with?("^") ||
        pattern.end_with?("$") ||
        pattern.include?(".*") ||
        pattern.include?("(") ||
        pattern.include?("[")
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/matcher_spec.rb
```

Expected: 7 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/matcher.rb spec/mock_openai/matcher_spec.rb
git commit -m "feat: add Matcher class"
```

---

### Task 5: ResponseBuilder

**Files:**
- Create: `lib/mock_openai/response_builder.rb`
- Create: `spec/mock_openai/response_builder_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/response_builder_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::ResponseBuilder do
  describe ".build" do
    subject(:response) { described_class.build(content: "Hello!", model: "mock-gpt-4") }

    it "returns a hash with the correct object type" do
      expect(response["object"]).to eq("chat.completion")
    end

    it "includes the content in choices[0].message.content" do
      expect(response.dig("choices", 0, "message", "content")).to eq("Hello!")
    end

    it "sets finish_reason to stop" do
      expect(response.dig("choices", 0, "finish_reason")).to eq("stop")
    end

    it "includes a mock id" do
      expect(response["id"]).to match(/\Amock-chatcmpl-/)
    end

    it "includes the model name" do
      expect(response["model"]).to eq("mock-gpt-4")
    end

    it "includes usage fields zeroed out" do
      expect(response["usage"]).to eq(
        "prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0
      )
    end

    it "includes a created timestamp" do
      expect(response["created"]).to be_a(Integer)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/response_builder_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::ResponseBuilder`

- [ ] **Step 3: Implement `ResponseBuilder`**

```ruby
# lib/mock_openai/response_builder.rb
# frozen_string_literal: true

require "securerandom"

module MockOpenAI
  class ResponseBuilder
    def self.build(content:, model: "mock-gpt-4")
      {
        "id" => "mock-chatcmpl-#{SecureRandom.hex(8)}",
        "object" => "chat.completion",
        "created" => Time.now.to_i,
        "model" => model,
        "choices" => [
          {
            "index" => 0,
            "message" => { "role" => "assistant", "content" => content },
            "finish_reason" => "stop"
          }
        ],
        "usage" => { "prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0 }
      }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/response_builder_spec.rb
```

Expected: 7 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/response_builder.rb spec/mock_openai/response_builder_spec.rb
git commit -m "feat: add ResponseBuilder class"
```

---

### Task 6: TemplateRenderer

**Files:**
- Create: `lib/mock_openai/template_renderer.rb`
- Create: `spec/mock_openai/template_renderer_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/template_renderer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::TemplateRenderer do
  let(:context) do
    { last_user_message: "Hello!", system_message: "You are helpful.", model: "gpt-4" }
  end

  describe ".render" do
    it "substitutes {{last_user_message}}" do
      result = described_class.render("Reply to: {{last_user_message}}", context)
      expect(result).to eq("Reply to: Hello!")
    end

    it "substitutes {{system_message}}" do
      result = described_class.render("System: {{system_message}}", context)
      expect(result).to eq("System: You are helpful.")
    end

    it "substitutes {{model}}" do
      result = described_class.render("Using {{model}}", context)
      expect(result).to eq("Using gpt-4")
    end

    it "substitutes multiple variables in one template" do
      result = described_class.render("{{model}}: {{last_user_message}}", context)
      expect(result).to eq("gpt-4: Hello!")
    end

    it "leaves unrecognized variables as-is" do
      result = described_class.render("{{unknown}}", context)
      expect(result).to eq("{{unknown}}")
    end

    it "returns the template unchanged when context values are nil" do
      ctx = { last_user_message: nil, system_message: nil, model: nil }
      result = described_class.render("Reply to: {{last_user_message}}", ctx)
      expect(result).to eq("Reply to: ")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/template_renderer_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::TemplateRenderer`

- [ ] **Step 3: Implement `TemplateRenderer`**

```ruby
# lib/mock_openai/template_renderer.rb
# frozen_string_literal: true

module MockOpenAI
  class TemplateRenderer
    VARIABLES = {
      "{{last_user_message}}" => ->(ctx) { ctx[:last_user_message].to_s },
      "{{system_message}}" => ->(ctx) { ctx[:system_message].to_s },
      "{{model}}" => ->(ctx) { ctx[:model].to_s }
    }.freeze

    def self.render(template, context)
      VARIABLES.reduce(template) do |result, (placeholder, extractor)|
        result.gsub(placeholder, extractor.call(context))
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/template_renderer_spec.rb
```

Expected: 6 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/template_renderer.rb spec/mock_openai/template_renderer_spec.rb
git commit -m "feat: add TemplateRenderer class"
```

---

## Chunk 3: Failure Modes

### Task 7: All Failure Mode Classes

**Files:**
- Create: `lib/mock_openai/failure_modes/base.rb`
- Create: `lib/mock_openai/failure_modes/timeout.rb`
- Create: `lib/mock_openai/failure_modes/rate_limit.rb`
- Create: `lib/mock_openai/failure_modes/malformed_json.rb`
- Create: `lib/mock_openai/failure_modes/internal_error.rb`
- Create: `lib/mock_openai/failure_modes/truncated_stream.rb`
- Create: `spec/mock_openai/failure_modes/timeout_spec.rb`
- Create: `spec/mock_openai/failure_modes/rate_limit_spec.rb`
- Create: `spec/mock_openai/failure_modes/malformed_json_spec.rb`
- Create: `spec/mock_openai/failure_modes/internal_error_spec.rb`
- Create: `spec/mock_openai/failure_modes/truncated_stream_spec.rb`

- [ ] **Step 1: Write failing tests for all 5 modes**

```ruby
# spec/mock_openai/failure_modes/timeout_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::Timeout do
  it "returns the :timeout symbol" do
    result = described_class.new.apply(request: {}, response: {})
    expect(result).to eq(:timeout)
  end
end
```

```ruby
# spec/mock_openai/failure_modes/rate_limit_spec.rb
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
```

```ruby
# spec/mock_openai/failure_modes/malformed_json_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::MalformedJson do
  subject(:result) { described_class.new.apply(request: {}, response: {}) }

  it "returns HTTP 200" do
    expect(result[0]).to eq(200)
  end

  it "returns a body that is not valid JSON" do
    expect { JSON.parse(result[2].first) }.to raise_error(JSON::ParserError)
  end
end
```

```ruby
# spec/mock_openai/failure_modes/internal_error_spec.rb
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
```

```ruby
# spec/mock_openai/failure_modes/truncated_stream_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::FailureModes::TruncatedStream do
  it "returns the :stream_truncated symbol" do
    result = described_class.new.apply(request: {}, response: {})
    expect(result).to eq(:stream_truncated)
  end
end
```

- [ ] **Step 2: Run tests to verify they all fail**

```bash
bundle exec rspec spec/mock_openai/failure_modes/
```

Expected: 7 examples, all FAIL — constants not defined

- [ ] **Step 3: Implement `FailureModes::Base`**

```ruby
# lib/mock_openai/failure_modes/base.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    REGISTRY = {} # populated by each subclass

    class Base
      def apply(request:, response:)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end
    end
  end
end
```

- [ ] **Step 4: Implement `FailureModes::Timeout`**

```ruby
# lib/mock_openai/failure_modes/timeout.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class Timeout < Base
      def apply(request:, response:)
        :timeout
      end
    end

    REGISTRY["timeout"] = Timeout
  end
end
```

- [ ] **Step 5: Implement `FailureModes::RateLimit`**

```ruby
# lib/mock_openai/failure_modes/rate_limit.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class RateLimit < Base
      def apply(request:, response:)
        body = {
          "error" => {
            "type" => "rate_limit_error",
            "message" => "Rate limit exceeded",
            "code" => "rate_limit_exceeded"
          }
        }
        [429, { "Content-Type" => "application/json" }, [body.to_json]]
      end
    end

    REGISTRY["rate_limit"] = RateLimit
  end
end
```

- [ ] **Step 6: Implement `FailureModes::MalformedJson`**

```ruby
# lib/mock_openai/failure_modes/malformed_json.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class MalformedJson < Base
      def apply(request:, response:)
        [200, { "Content-Type" => "application/json" }, ['{ "choices": [ ']]
      end
    end

    REGISTRY["malformed_json"] = MalformedJson
  end
end
```

- [ ] **Step 7: Implement `FailureModes::InternalError`**

```ruby
# lib/mock_openai/failure_modes/internal_error.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class InternalError < Base
      def apply(request:, response:)
        body = {
          "error" => {
            "type" => "server_error",
            "message" => "Internal server error"
          }
        }
        [500, { "Content-Type" => "application/json" }, [body.to_json]]
      end
    end

    REGISTRY["internal_error"] = InternalError
  end
end
```

- [ ] **Step 8: Implement `FailureModes::TruncatedStream`**

```ruby
# lib/mock_openai/failure_modes/truncated_stream.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    class TruncatedStream < Base
      def apply(request:, response:)
        :stream_truncated
      end
    end

    REGISTRY["truncated_stream"] = TruncatedStream
  end
end
```

- [ ] **Step 9: Add `FailureModes.apply` class method — replace `base.rb` with complete final version**

```ruby
# lib/mock_openai/failure_modes/base.rb
# frozen_string_literal: true

module MockOpenAI
  module FailureModes
    REGISTRY = {} # populated by each subclass on require

    def self.apply(mode, request:, response:)
      key = mode.to_s
      klass = REGISTRY.fetch(key) { raise ArgumentError, "Unknown failure mode: #{mode}" }
      klass.new.apply(request: request, response: response)
    end

    class Base
      def apply(request:, response:)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end
    end
  end
end
```

- [ ] **Step 10: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/failure_modes/
```

Expected: 7 examples, 0 failures

- [ ] **Step 11: Commit**

```bash
git add lib/mock_openai/failure_modes/ spec/mock_openai/failure_modes/
git commit -m "feat: add failure mode classes"
```

---

## Chunk 4: Handler + Router

### Task 8: ChatCompletions Handler

**Files:**
- Create: `lib/mock_openai/handlers/chat_completions.rb`
- Create: `spec/mock_openai/handlers/chat_completions_spec.rb`

The handler is a Rack endpoint. Tests use `rack-test` to call it directly without a running server.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/handlers/chat_completions_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::ChatCompletions do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_request) do
    {
      "model" => "gpt-4",
      "messages" => [
        { "role" => "system", "content" => "You are helpful." },
        { "role" => "user", "content" => "Hello" }
      ]
    }
  end

  def post_chat(body = valid_request)
    post "/v1/chat/completions", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  context "with no rules in state" do
    it "returns HTTP 200" do
      post_chat
      expect(last_response.status).to eq(200)
    end

    it "returns JSON with the default response in choices[0]" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq(MockOpenAI.config.default_response)
    end

    it "returns Content-Type application/json" do
      post_chat
      expect(last_response.content_type).to include("application/json")
    end
  end

  context "with a matching rule" do
    before do
      MockOpenAI::State.write(rules: [{ "match" => "Hello", "response" => "Hi there!" }])
    end

    it "returns the matched response" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("Hi there!")
    end
  end

  context "with a template rule" do
    before do
      MockOpenAI::State.write(rules: [
        { "match" => ".*", "template" => "You said: {{last_user_message}}" }
      ])
    end

    it "renders the template with the user message" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("You said: Hello")
    end
  end

  context "with a failure_mode rule" do
    before do
      MockOpenAI::State.write(rules: [{ "match" => ".*", "failure_mode" => "rate_limit" }])
    end

    it "returns 429" do
      post_chat
      expect(last_response.status).to eq(429)
    end
  end

  context "when request body is not valid JSON" do
    it "returns HTTP 400" do
      post "/v1/chat/completions", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "with multiple rules" do
    before do
      MockOpenAI::State.write(rules: [
        { "match" => "Hello", "response" => "Hi!" },
        { "match" => ".*", "response" => "fallback" }
      ])
    end

    it "matches the first applicable rule" do
      post_chat
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("Hi!")
    end
  end

  it "logs the request to stdout" do
    expect do
      post_chat
    end.to output(/\[MockOpenAI\] POST \/v1\/chat\/completions/).to_stdout
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/handlers/chat_completions_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::Handlers`

- [ ] **Step 3: Implement `Handlers::ChatCompletions`**

```ruby
# lib/mock_openai/handlers/chat_completions.rb
# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class ChatCompletions
      JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

      def call(env)
        request = Rack::Request.new(env)
        parsed = parse_body(request.body.read)
        return error_response(400, "invalid_request_error", "Request body must be valid JSON") unless parsed

        state = State.read
        last_user_message = extract_last_user_message(parsed)
        model = parsed["model"] || "mock-gpt-4"
        system_message = parsed["messages"]&.find { |m| m["role"] == "system" }&.dig("content")

        rule = Matcher.match(state["rules"] || [], last_user_message.to_s)

        result = resolve_rule(rule, state, last_user_message, system_message, model)
        log_request(env, rule ? (state["rules"] || []).index(rule) : nil, rule&.dig("failure_mode"))
        result
      end

      private

      def parse_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def extract_last_user_message(parsed)
        messages = parsed["messages"] || []
        messages.reverse.find { |m| m["role"] == "user" }&.dig("content")
      end

      def resolve_rule(rule, state, last_user_message, system_message, model)
        context = { last_user_message: last_user_message, system_message: system_message, model: model }

        if rule
          if rule["failure_mode"]
            result = FailureModes.apply(rule["failure_mode"], request: {}, response: {})
            return handle_symbol_result(result) if result.is_a?(Symbol)
            return result
          elsif rule["response"]
            return success_response(rule["response"], model)
          elsif rule["template"]
            return success_response(TemplateRenderer.render(rule["template"], context), model)
          end
        end

        # No rule matched — use global fallback
        if state["response_template"]
          return success_response(TemplateRenderer.render(state["response_template"], context), model)
        end

        fallback = state["default_response"] || MockOpenAI.config.default_response
        success_response(fallback, model)
      end

      def handle_symbol_result(symbol)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          [200, JSON_HEADERS, [{ "choices" => [] }.to_json]]
        when :stream_truncated
          truncated_sse_response
        end
      end

      def truncated_sse_response
        chunks = [
          "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
          "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
        ]
        [200, { "Content-Type" => "text/event-stream" }, chunks]
      end

      def success_response(content, model)
        response = ResponseBuilder.build(content: content, model: model)
        [200, JSON_HEADERS, [response.to_json]]
      end

      def error_response(status, type, message)
        body = { "error" => { "type" => type, "message" => message } }
        [status, JSON_HEADERS, [body.to_json]]
      end

      def log_request(env, rule_index, failure_mode)
        method = env["REQUEST_METHOD"]
        path = env["PATH_INFO"]
        rule_label = rule_index.nil? ? "none" : rule_index.to_s
        mode_label = failure_mode.nil? ? "none" : failure_mode.to_s
        puts "[MockOpenAI] #{method} #{path} | rule=#{rule_label} | mode=#{mode_label}"
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/handlers/chat_completions_spec.rb
```

Expected: 9 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/handlers/ spec/mock_openai/handlers/
git commit -m "feat: add ChatCompletions handler"
```

---

### Task 9: Router

**Files:**
- Create: `lib/mock_openai/router.rb`
- Create: `spec/mock_openai/router_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/router_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Router do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_body) do
    { "model" => "gpt-4", "messages" => [{ "role" => "user", "content" => "hi" }] }.to_json
  end

  it "routes POST /v1/chat/completions to ChatCompletions handler" do
    post "/v1/chat/completions", valid_body, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body["object"]).to eq("chat.completion")
  end

  it "returns 404 for unknown routes" do
    get "/unknown"
    expect(last_response.status).to eq(404)
    body = JSON.parse(last_response.body)
    expect(body.dig("error", "type")).to eq("invalid_request_error")
  end

  it "returns 404 for wrong method on a known path" do
    get "/v1/chat/completions"
    expect(last_response.status).to eq(404)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/router_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::Router`

- [ ] **Step 3: Implement `Router`**

```ruby
# lib/mock_openai/router.rb
# frozen_string_literal: true

module MockOpenAI
  class Router
    NOT_FOUND_BODY = {
      "error" => { "type" => "invalid_request_error", "message" => "Not found" }
    }.to_json.freeze

    def call(env)
      request = Rack::Request.new(env)

      case [request.request_method, request.path_info]
      in ["POST", "/v1/chat/completions"]
        Handlers::ChatCompletions.new.call(env)
      else
        [404, { "Content-Type" => "application/json" }, [NOT_FOUND_BODY]]
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/router_spec.rb
```

Expected: 3 examples, 0 failures

- [ ] **Step 5: Run all specs to make sure nothing broke**

```bash
bundle exec rspec
```

Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add lib/mock_openai/router.rb spec/mock_openai/router_spec.rb
git commit -m "feat: add Router"
```

---

## Chunk 5: Server + Public API + RSpec Integration + CLI

### Task 10: Server

**Files:**
- Create: `lib/mock_openai/server.rb`
- Create: `spec/mock_openai/server_spec.rb`

The server spec focuses on setup behaviour (tmp dir creation, state file initialisation). It stubs the Rack runner to avoid actually binding to a port.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai/server_spec.rb
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
      existing = { "rules" => [{ "match" => "hi", "response" => "hello" }], "metadata" => {} }
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/server_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::Server`

- [ ] **Step 3: Implement `Server`**

```ruby
# lib/mock_openai/server.rb
# frozen_string_literal: true

require "fileutils"

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
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/server_spec.rb
```

Expected: 4 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/mock_openai/server.rb spec/mock_openai/server_spec.rb
git commit -m "feat: add Server class"
```

---

### Task 11: MockOpenAI Public API

The top-level `lib/mock_openai.rb` already contains the public API (written in Task 1). This task adds the spec to confirm it wires up correctly.

**Files:**
- Create: `spec/mock_openai_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/mock_openai_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI do
  describe ".set_responses" do
    it "writes rules to the state file" do
      rules = [{ match: "Hello", response: "Hi!" }]
      MockOpenAI.set_responses(rules)

      state = MockOpenAI::State.read
      expect(state["rules"].first["match"]).to eq("Hello")
      expect(state["rules"].first["response"]).to eq("Hi!")
    end

    it "converts symbol keys to string keys" do
      MockOpenAI.set_responses([{ match: "hi", failure_mode: :timeout }])
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
```

- [ ] **Step 2: Run the tests**

```bash
bundle exec rspec spec/mock_openai_spec.rb
```

Expected: 6 examples, 0 failures (the public API was scaffolded in Task 1 Step 4 and should be complete)

- [ ] **Step 3: Run all specs**

```bash
bundle exec rspec
```

Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add spec/mock_openai_spec.rb
git commit -m "test: add public API spec"
```

---

### Task 12: RSpec Integration

**Files:**
- Create: `lib/mock_openai/rspec/metadata.rb`
- Create: `spec/mock_openai/rspec/metadata_spec.rb`
- Create: `spec/integration/rspec_metadata_spec.rb`

- [ ] **Step 1: Write the failing test for the metadata module**

```ruby
# spec/mock_openai/rspec/metadata_spec.rb
# frozen_string_literal: true

require "spec_helper"

# Note: These tests verify the module's hook registration, not the hooks themselves
# (which are tested in spec/integration/rspec_metadata_spec.rb).
RSpec.describe MockOpenAI::RSpec::Metadata do
  it "is loadable without raising" do
    expect { require "mock_openai/rspec" }.not_to raise_error
  end
end
```

```ruby
# spec/integration/rspec_metadata_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "mock_openai/rspec"

# These specs verify end-to-end: metadata tag → state written → correct server behaviour.
# They use the Router directly via rack-test (no running server needed).
RSpec.describe "RSpec metadata integration", :mock_openai do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def post_chat(user_message)
    body = {
      "model" => "gpt-4",
      "messages" => [{ "role" => "user", "content" => user_message }]
    }.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
  end

  it "state is empty at the start of a :mock_openai test" do
    expect(MockOpenAI::State.read["rules"]).to eq([])
  end

  context "when rules are set within the test" do
    it "returns the matched response" do
      MockOpenAI.set_responses([{ match: "ping", response: "pong" }])
      post_chat("ping")
      body = JSON.parse(last_response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("pong")
    end
  end
end

RSpec.describe "shortcut failure mode tags" do
  include Rack::Test::Methods

  def app
    MockOpenAI::Router.new
  end

  def post_chat
    body = { "model" => "gpt-4", "messages" => [{ "role" => "user", "content" => "hi" }] }.to_json
    post "/v1/chat/completions", body, "CONTENT_TYPE" => "application/json"
  end

  it "sets rate_limit failure mode", :mock_openai_rate_limit do
    post_chat
    expect(last_response.status).to eq(429)
  end

  it "sets internal_error failure mode", :mock_openai_internal_error do
    post_chat
    expect(last_response.status).to eq(500)
  end

  it "sets malformed_json failure mode", :mock_openai_malformed_json do
    post_chat
    expect { JSON.parse(last_response.body) }.to raise_error(JSON::ParserError)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/mock_openai/rspec/ spec/integration/
```

Expected: FAIL — `uninitialized constant MockOpenAI::RSpec`

- [ ] **Step 3: Implement `RSpec::Metadata`**

```ruby
# lib/mock_openai/rspec/metadata.rb
# frozen_string_literal: true

module MockOpenAI
  module RSpec
    module Metadata
      FAILURE_MODE_TAGS = {
        mock_openai_timeout: :timeout,
        mock_openai_rate_limit: :rate_limit,
        mock_openai_malformed_json: :malformed_json,
        mock_openai_internal_error: :internal_error,
        mock_openai_truncated_stream: :truncated_stream
      }.freeze
    end
  end
end

::RSpec.configure do |config|
  # Generic tag: reset state before test
  config.before(:each, :mock_openai) do
    MockOpenAI.reset!
  end

  # Shortcut failure mode tags: reset then set mode
  MockOpenAI::RSpec::Metadata::FAILURE_MODE_TAGS.each do |tag, mode|
    config.before(:each, tag) do
      MockOpenAI.reset!
      MockOpenAI.set_failure_mode(mode)
    end
  end

  # Reset after any mock_openai-tagged test
  config.after(:each) do |example|
    if example.metadata.keys.any? { |k| k.to_s.start_with?("mock_openai") }
      MockOpenAI.reset!
    end
  end
end
```

- [ ] **Step 4: Create `lib/mock_openai/rspec.rb`** (no change to `lib/mock_openai.rb` needed — users opt in by calling `require "mock_openai/rspec"` themselves)

Create `lib/mock_openai/rspec.rb`:

```ruby
# lib/mock_openai/rspec.rb
# frozen_string_literal: true

require "mock_openai"
require "mock_openai/rspec/metadata"
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/rspec/ spec/integration/
```

Expected: All pass

- [ ] **Step 6: Run full suite**

```bash
bundle exec rspec
```

Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add lib/mock_openai/rspec.rb lib/mock_openai/rspec/ spec/mock_openai/rspec/ spec/integration/
git commit -m "feat: add RSpec metadata integration"
```

---

### Task 13: CLI

**Files:**
- Create: `lib/mock_openai/cli.rb`
- Create: `bin/mock-openai`
- Create: `spec/mock_openai/cli_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/mock_openai/cli_spec.rb
```

Expected: FAIL — `uninitialized constant MockOpenAI::CLI`

- [ ] **Step 3: Implement `CLI`**

```ruby
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
```

- [ ] **Step 4: Create `bin/mock-openai`**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/mock_openai"

MockOpenAI::CLI.run(ARGV)
```

- [ ] **Step 5: Make the binary executable**

```bash
chmod +x bin/mock-openai
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bundle exec rspec spec/mock_openai/cli_spec.rb
```

Expected: 6 examples, 0 failures

- [ ] **Step 7: Run full suite**

```bash
bundle exec rspec
```

Expected: All pass

- [ ] **Step 8: Verify the binary works**

```bash
bundle exec ruby bin/mock-openai check
```

Expected: prints port/timeout/response/state_file config

- [ ] **Step 9: Commit**

```bash
git add lib/mock_openai/cli.rb bin/mock-openai spec/mock_openai/cli_spec.rb
git commit -m "feat: add CLI"
```

---

## Final Verification

- [ ] **Run the full test suite one last time**

```bash
bundle exec rspec --format documentation
```

Expected: All examples pass, 0 failures

- [ ] **Run StandardRB**

```bash
bundle exec standardrb
```

Expected: No offenses (or fix any reported)

- [ ] **Smoke test the CLI**

```bash
bundle exec ruby bin/mock-openai check
bundle exec ruby bin/mock-openai init
```

Expected: Config output; creates `mock_openai.yml`

- [ ] **Commit any StandardRB fixes**

```bash
git add -u
git commit -m "style: standardrb fixes"
```
