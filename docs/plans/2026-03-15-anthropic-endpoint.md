# Anthropic Endpoint Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `POST /v1/messages` (Anthropic API endpoint) to MockOpenAI so clients using RubyLLM's Anthropic provider can use MockOpenAI without switching providers.

**Architecture:** Extract shared handler logic into `Handlers::Base` using the template method pattern. `ChatCompletions` and the new `Messages` handler each extend `Base` and implement three provider-specific methods. A new `AnthropicResponseBuilder` produces the correct Anthropic response envelope.

**Tech Stack:** Ruby, Rack, RSpec, rack-test

---

## Chunk 1: AnthropicResponseBuilder + Handlers::Base

### Task 1: AnthropicResponseBuilder

**Files:**
- Create: `lib/mock_openai/anthropic_response_builder.rb`
- Create: `spec/mock_openai/anthropic_response_builder_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/mock_openai/anthropic_response_builder_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::AnthropicResponseBuilder do
  describe ".build" do
    subject(:response) { described_class.build(content: "Hello!", model: "mock-claude-3") }

    it "returns type 'message'" do
      expect(response["type"]).to eq("message")
    end

    it "sets role to 'assistant'" do
      expect(response["role"]).to eq("assistant")
    end

    it "places content in content[0].text" do
      expect(response.dig("content", 0, "text")).to eq("Hello!")
    end

    it "sets content[0].type to 'text'" do
      expect(response.dig("content", 0, "type")).to eq("text")
    end

    it "sets stop_reason to 'end_turn'" do
      expect(response["stop_reason"]).to eq("end_turn")
    end

    it "includes a mock-msg- prefixed id" do
      expect(response["id"]).to match(/\Amock-msg-/)
    end

    it "includes the model name" do
      expect(response["model"]).to eq("mock-claude-3")
    end

    it "includes usage with input_tokens and output_tokens" do
      expect(response["usage"]).to eq("input_tokens" => 0, "output_tokens" => 0)
    end

    it "generates unique ids on each call" do
      r1 = described_class.build(content: "a")
      r2 = described_class.build(content: "b")
      expect(r1["id"]).not_to eq(r2["id"])
    end

    it "uses mock-claude-3 as the default model" do
      r = described_class.build(content: "x")
      expect(r["model"]).to eq("mock-claude-3")
    end
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
cd /Users/tracy/projects/mockopenai
bundle exec rspec spec/mock_openai/anthropic_response_builder_spec.rb
```

Expected: All examples fail with `NameError: uninitialized constant MockOpenAI::AnthropicResponseBuilder`

- [ ] **Step 3: Implement AnthropicResponseBuilder**

Create `lib/mock_openai/anthropic_response_builder.rb`:

```ruby
# frozen_string_literal: true

require "securerandom"

module MockOpenAI
  class AnthropicResponseBuilder
    def self.build(content:, model: "mock-claude-3")
      {
        "id"            => "mock-msg-#{SecureRandom.hex(8)}",
        "type"          => "message",
        "role"          => "assistant",
        "content"       => [{"type" => "text", "text" => content}],
        "model"         => model,
        "stop_reason"   => "end_turn",
        "stop_sequence" => nil,
        "usage"         => {"input_tokens" => 0, "output_tokens" => 0}
      }
    end
  end
end
```

- [ ] **Step 4: Add require to lib/mock_openai.rb**

In `lib/mock_openai.rb`, add after the `response_builder` require line:

```ruby
require_relative "mock_openai/anthropic_response_builder"
```

- [ ] **Step 5: Run spec to confirm it passes**

```bash
bundle exec rspec spec/mock_openai/anthropic_response_builder_spec.rb
```

Expected: 10 examples, 0 failures

- [ ] **Step 6: Run full suite to confirm nothing broken**

```bash
bundle exec rspec
```

Expected: All existing examples pass

- [ ] **Step 7: Commit**

```bash
git add lib/mock_openai/anthropic_response_builder.rb \
        lib/mock_openai.rb \
        spec/mock_openai/anthropic_response_builder_spec.rb
git commit -m "feat: add AnthropicResponseBuilder"
```

---

### Task 2: Handlers::Base

**Files:**
- Create: `lib/mock_openai/handlers/base.rb`
- Create: `spec/mock_openai/handlers/base_spec.rb`

- [ ] **Step 1: Write the failing spec**

The spec tests `Base` via a minimal concrete double — a subclass that implements the three template methods with neutral test values. This avoids coupling to either provider's format.

Create `spec/mock_openai/handlers/base_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::Base do
  include Rack::Test::Methods

  # Anonymous subclass avoids top-level constant pollution and collision risk
  # if specs are reorganised. Returns a neutral JSON body so tests can inspect
  # content without caring about OpenAI vs Anthropic envelope format.
  let(:handler_class) do
    Class.new(MockOpenAI::Handlers::Base) do
      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message: body["system"].to_s,
          model: body["model"] || "test-model"
        }
      end

      def build_success_response(content, model)
        [200, {"Content-Type" => "application/json"},
         [{"test_content" => content, "test_model" => model}.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        [599, {"Content-Type" => "application/json"},
         [{"failure_mode_applied" => mode, "model" => request_context[:model]}.to_json]]
      end
    end
  end

  def app
    handler_class.new
  end

  def post_messages(body)
    post "/v1/messages", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  let(:valid_request) do
    {
      "model" => "claude-3",
      "messages" => [{"role" => "user", "content" => "Hello"}]
    }
  end

  context "with no rules in state" do
    it "returns 200" do
      post_messages(valid_request)
      expect(last_response.status).to eq(200)
    end

    it "uses the config default_response as content" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq(MockOpenAI.config.default_response)
    end

    it "passes the model from the request" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_model"]).to eq("claude-3")
    end
  end

  context "content resolution — five-step fallback chain" do
    it "step 1: uses rule response when rule matches" do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "rule response"}])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("rule response")
    end

    it "step 2: renders rule template when rule has template" do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "echo: {{last_user_message}}"}
      ])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("echo: Hello")
    end

    it "step 3: uses state response_template when no rule matches" do
      MockOpenAI::State.write(
        rules: [],
        response_template: "global: {{last_user_message}}"
      )
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("global: Hello")
    end

    it "step 4: uses state default_response when no rule and no response_template" do
      MockOpenAI::State.write(rules: [], default_response: "state default")
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("state default")
    end

    it "step 5: uses config default_response as final fallback" do
      MockOpenAI::State.write(rules: [])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq(MockOpenAI.config.default_response)
    end
  end

  context "failure mode dispatch" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "rate_limit"}])
    end

    it "delegates to apply_failure_mode with the mode string" do
      post_messages(valid_request)
      expect(last_response.status).to eq(599)
      body = JSON.parse(last_response.body)
      expect(body["failure_mode_applied"]).to eq("rate_limit")
    end

    it "passes request_context to apply_failure_mode" do
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["model"]).to eq("claude-3")
    end
  end

  context "with invalid JSON body" do
    it "returns 400" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
    end

    it "returns an invalid_request_error" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "extract_text_content helper" do
    it "normalizes a content-block array to plain text" do
      request = {
        "model" => "claude-3",
        "messages" => [
          {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
        ]
      }
      MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
      post_messages(request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("matched")
    end

    it "passes a plain string through unchanged" do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "matched plain"}])
      post_messages(valid_request)
      body = JSON.parse(last_response.body)
      expect(body["test_content"]).to eq("matched plain")
    end
  end

  it "logs the request to stdout" do
    expect { post_messages(valid_request) }.to output(/\[MockOpenAI\]/).to_stdout
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/mock_openai/handlers/base_spec.rb
```

Expected: All examples fail with `NameError: uninitialized constant MockOpenAI::Handlers::Base`

- [ ] **Step 3: Implement Handlers::Base**

Create `lib/mock_openai/handlers/base.rb`:

```ruby
# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class Base
      JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

      def call(env)
        request = Rack::Request.new(env)
        parsed = parse_json_body(request.body.read)
        return error_response(400, "invalid_request_error", "Request body must be valid JSON") unless parsed

        request_context = parse_request(parsed)
        state = State.read
        rule = Matcher.match(state["rules"] || [], request_context[:last_user_message].to_s)

        result = resolve_content(rule, state, request_context)
        log_request(env, rule ? (state["rules"] || []).index(rule) : nil, rule&.dig("failure_mode"))
        result
      end

      private

      # Template methods — subclasses must implement all three

      def parse_request(body)
        raise NotImplementedError, "#{self.class} must implement #parse_request"
      end

      def build_success_response(content, model)
        raise NotImplementedError, "#{self.class} must implement #build_success_response"
      end

      def apply_failure_mode(mode, request_context)
        raise NotImplementedError, "#{self.class} must implement #apply_failure_mode"
      end

      # Shared helpers

      def extract_text_content(content)
        if content.is_a?(Array)
          content.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
        else
          content.to_s
        end
      end

      def resolve_content(rule, state, request_context)
        model = request_context[:model]

        if rule
          if rule["failure_mode"]
            return apply_failure_mode(rule["failure_mode"], request_context)
          elsif rule["response"]
            return build_success_response(rule["response"], model)
          elsif rule["template"]
            return build_success_response(
              TemplateRenderer.render(rule["template"], request_context), model
            )
          end
        end

        if state["response_template"]
          return build_success_response(
            TemplateRenderer.render(state["response_template"], request_context), model
          )
        end

        fallback = state["default_response"] || MockOpenAI.config.default_response
        build_success_response(fallback, model)
      end

      def parse_json_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def error_response(status, type, message)
        body = {"error" => {"type" => type, "message" => message}}
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

> **Note:** `log_request` fires _after_ `resolve_content` returns. For `:timeout`, this means logging happens after the sleep — consistent with the existing `ChatCompletions` behavior.


- [ ] **Step 4: Add require to lib/mock_openai.rb**

In `lib/mock_openai.rb`, add `handlers/base` _before_ `handlers/chat_completions`:

```ruby
require_relative "mock_openai/handlers/base"
require_relative "mock_openai/handlers/chat_completions"
```

- [ ] **Step 5: Run spec to confirm it passes**

```bash
bundle exec rspec spec/mock_openai/handlers/base_spec.rb
```

Expected: All examples pass

- [ ] **Step 6: Run full suite**

```bash
bundle exec rspec
```

Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add lib/mock_openai/handlers/base.rb \
        lib/mock_openai.rb \
        spec/mock_openai/handlers/base_spec.rb
git commit -m "feat: add Handlers::Base with shared call(env) flow"
```

---

## Chunk 2: Refactor ChatCompletions + Messages handler + Router

### Task 3: Refactor ChatCompletions to extend Base

**Files:**
- Modify: `lib/mock_openai/handlers/chat_completions.rb`
- Modify: `spec/mock_openai/handlers/chat_completions_spec.rb`

The existing `ChatCompletions` spec covers OpenAI-specific behavior and should continue to pass. The refactor moves shared logic up to `Base` and introduces one intentional behavior improvement: `parse_request` now calls `extract_text_content`, which normalizes content-block arrays (e.g. vision requests) to plain text before matching. The previous code passed the raw array object to `Matcher`, which silently stringified it. We add a test to document this.

- [ ] **Step 1: Run existing spec to establish baseline**

```bash
bundle exec rspec spec/mock_openai/handlers/chat_completions_spec.rb
```

Expected: All examples pass. This is the baseline to maintain.

- [ ] **Step 2: Add test for content-block array normalization to chat_completions_spec.rb**

Add this context block inside the existing `RSpec.describe MockOpenAI::Handlers::ChatCompletions` block (e.g. after the existing "with a matching rule" context):

```ruby
context "with a content-block array as user message (vision format)" do
  before do
    MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
  end

  it "normalizes the content-block array to plain text for rule matching" do
    body = {
      "model" => "gpt-4",
      "messages" => [
        {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
      ]
    }
    post "/v1/chat/completions", body.to_json, "CONTENT_TYPE" => "application/json"
    response_body = JSON.parse(last_response.body)
    expect(response_body.dig("choices", 0, "message", "content")).to eq("matched")
  end
end
```

- [ ] **Step 3: Run spec to confirm new test fails**

```bash
bundle exec rspec spec/mock_openai/handlers/chat_completions_spec.rb
```

Expected: The new example fails (current code passes the raw array to `Matcher`), all others pass.

- [ ] **Step 4: Refactor ChatCompletions to extend Base**

Replace `lib/mock_openai/handlers/chat_completions.rb` entirely:

```ruby
# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class ChatCompletions < Base
      private

      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        system_msg = messages.find { |m| m["role"] == "system" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message:    extract_text_content(system_msg&.dig("content")),
          model:             body["model"] || "mock-gpt-4"
        }
      end

      def build_success_response(content, model)
        response = ResponseBuilder.build(content: content, model: model)
        [200, JSON_HEADERS, [response.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        result = FailureModes.apply(mode, request: {}, response: {})
        return handle_symbol_result(result) if result.is_a?(Symbol)
        result
      end

      def handle_symbol_result(symbol)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          [200, JSON_HEADERS, [{"choices" => []}.to_json]]
        when :stream_truncated
          chunks = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
          ]
          [200, {"Content-Type" => "text/event-stream"}, chunks]
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run ChatCompletions spec to confirm all examples pass**

```bash
bundle exec rspec spec/mock_openai/handlers/chat_completions_spec.rb
```

Expected: All examples pass including the new content-block normalization test

- [ ] **Step 6: Run full suite**

```bash
bundle exec rspec
```

Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add lib/mock_openai/handlers/chat_completions.rb \
        spec/mock_openai/handlers/chat_completions_spec.rb
git commit -m "refactor: ChatCompletions extends Handlers::Base"
```

---

### Task 4: Handlers::Messages (Anthropic endpoint)

**Files:**
- Create: `lib/mock_openai/handlers/messages.rb`
- Create: `spec/mock_openai/handlers/messages_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/mock_openai/handlers/messages_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe MockOpenAI::Handlers::Messages do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  let(:valid_request) do
    {
      "model"    => "claude-3-haiku",
      "system"   => "You are helpful.",
      "messages" => [{"role" => "user", "content" => "Hello"}]
    }
  end

  def post_messages(body = valid_request)
    post "/v1/messages", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  context "with no rules in state" do
    it "returns HTTP 200" do
      post_messages
      expect(last_response.status).to eq(200)
    end

    it "returns Anthropic-format response with default content" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq(MockOpenAI.config.default_response)
    end

    it "sets type to 'message'" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body["type"]).to eq("message")
    end

    it "sets stop_reason to 'end_turn'" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body["stop_reason"]).to eq("end_turn")
    end

    it "returns Content-Type application/json" do
      post_messages
      expect(last_response.content_type).to include("application/json")
    end
  end

  context "with a matching rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => "Hello", "response" => "Hi there!"}])
    end

    it "returns the matched response in content[0].text" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("Hi there!")
    end
  end

  context "with a template rule" do
    before do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "You said: {{last_user_message}}"}
      ])
    end

    it "renders the template with the user message" do
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("You said: Hello")
    end

    it "makes the system message available to templates" do
      MockOpenAI::State.write(rules: [
        {"match" => ".*", "template" => "system: {{system_message}}"}
      ])
      post_messages
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("system: You are helpful.")
    end
  end

  context "with a failure_mode rule" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "rate_limit"}])
    end

    it "returns 429" do
      post_messages
      expect(last_response.status).to eq(429)
    end
  end

  context "with timeout failure mode" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "timeout"}])
      allow(MockOpenAI.config).to receive(:timeout_seconds).and_return(0)
    end

    it "returns 200 with an Anthropic-format error body" do
      post_messages
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["type"]).to eq("error")
    end
  end

  context "with truncated_stream failure mode" do
    before do
      MockOpenAI::State.write(rules: [{"match" => ".*", "failure_mode" => "truncated_stream"}])
    end

    it "returns text/event-stream content type" do
      post_messages
      expect(last_response.content_type).to include("text/event-stream")
    end

    it "returns Anthropic SSE chunk format" do
      post_messages
      expect(last_response.body).to include("content_block_delta")
    end
  end

  context "when request body is not valid JSON" do
    it "returns HTTP 400" do
      post "/v1/messages", "not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body)
      expect(body.dig("error", "type")).to eq("invalid_request_error")
    end
  end

  context "with content-block array as user message" do
    it "normalizes to plain text for matching" do
      MockOpenAI::State.write(rules: [{"match" => "Hello from block", "response" => "matched"}])
      request = {
        "model"    => "claude-3-haiku",
        "messages" => [
          {"role" => "user", "content" => [{"type" => "text", "text" => "Hello from block"}]}
        ]
      }
      post_messages(request)
      body = JSON.parse(last_response.body)
      expect(body.dig("content", 0, "text")).to eq("matched")
    end
  end

  it "logs the request to stdout" do
    expect { post_messages }.to output(/\[MockOpenAI\] POST \/v1\/messages/).to_stdout
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/mock_openai/handlers/messages_spec.rb
```

Expected: All examples fail with `NameError: uninitialized constant MockOpenAI::Handlers::Messages`

- [ ] **Step 3: Implement Handlers::Messages**

Create `lib/mock_openai/handlers/messages.rb`:

```ruby
# frozen_string_literal: true

module MockOpenAI
  module Handlers
    class Messages < Base
      private

      def parse_request(body)
        messages = body["messages"] || []
        last_user = messages.reverse.find { |m| m["role"] == "user" }
        {
          last_user_message: extract_text_content(last_user&.dig("content")),
          system_message:    body["system"].to_s,
          model:             body["model"] || "mock-claude-3"
        }
      end

      def build_success_response(content, model)
        response = AnthropicResponseBuilder.build(content: content, model: model)
        [200, JSON_HEADERS, [response.to_json]]
      end

      def apply_failure_mode(mode, request_context)
        result = FailureModes.apply(mode, request: {}, response: {})
        return handle_symbol_result(result, request_context) if result.is_a?(Symbol)
        result
      end

      def handle_symbol_result(symbol, request_context)
        case symbol
        when :timeout
          sleep(MockOpenAI.config.timeout_seconds)
          error_body = {"type" => "error", "error" => {"type" => "overloaded_error", "message" => "Overloaded"}}
          [200, JSON_HEADERS, [error_body.to_json]]
        when :stream_truncated
          chunks = [
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\" world\"}}\n\n"
          ]
          [200, {"Content-Type" => "text/event-stream"}, chunks]
        end
      end
    end
  end
end
```

- [ ] **Step 4: Add require to lib/mock_openai.rb**

In `lib/mock_openai.rb`, add after the `handlers/chat_completions` require:

```ruby
require_relative "mock_openai/handlers/messages"
```

- [ ] **Step 5: Run spec to confirm it passes**

```bash
bundle exec rspec spec/mock_openai/handlers/messages_spec.rb
```

Expected: All examples pass

- [ ] **Step 6: Run full suite**

```bash
bundle exec rspec
```

Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add lib/mock_openai/handlers/messages.rb \
        lib/mock_openai.rb \
        spec/mock_openai/handlers/messages_spec.rb
git commit -m "feat: add Handlers::Messages for Anthropic /v1/messages endpoint"
```

---

### Task 5: Router — add /v1/messages route

**Files:**
- Modify: `lib/mock_openai/router.rb`
- Modify: `spec/mock_openai/router_spec.rb`

- [ ] **Step 1: Write the failing router spec test**

Add to `spec/mock_openai/router_spec.rb` (inside the existing `RSpec.describe` block):

```ruby
let(:anthropic_body) do
  {
    "model"    => "claude-3-haiku",
    "messages" => [{"role" => "user", "content" => "hi"}]
  }.to_json
end

it "routes POST /v1/messages to Messages handler" do
  post "/v1/messages", anthropic_body, "CONTENT_TYPE" => "application/json"
  expect(last_response.status).to eq(200)
  body = JSON.parse(last_response.body)
  expect(body["type"]).to eq("message")
end
```

- [ ] **Step 2: Run router spec to confirm new test fails**

```bash
bundle exec rspec spec/mock_openai/router_spec.rb
```

Expected: New example fails with 404; existing examples pass

- [ ] **Step 3: Add route to Router**

In `lib/mock_openai/router.rb`, add the new route inside the `case` statement:

```ruby
in ["POST", "/v1/messages"]
  Handlers::Messages.new.call(env)
```

Full updated file:

```ruby
# frozen_string_literal: true

module MockOpenAI
  class Router
    NOT_FOUND_BODY = {
      "error" => {"type" => "invalid_request_error", "message" => "Not found"}
    }.to_json.freeze

    def call(env)
      request = Rack::Request.new(env)

      case [request.request_method, request.path_info]
      in ["POST", "/v1/chat/completions"]
        Handlers::ChatCompletions.new.call(env)
      in ["POST", "/v1/messages"]
        Handlers::Messages.new.call(env)
      else
        [404, {"Content-Type" => "application/json"}, [NOT_FOUND_BODY]]
      end
    end
  end
end
```

- [ ] **Step 4: Run router spec to confirm all tests pass**

```bash
bundle exec rspec spec/mock_openai/router_spec.rb
```

Expected: All examples pass

- [ ] **Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: All examples pass

- [ ] **Step 6: Commit**

```bash
git add lib/mock_openai/router.rb spec/mock_openai/router_spec.rb
git commit -m "feat: route POST /v1/messages to Handlers::Messages"
```
