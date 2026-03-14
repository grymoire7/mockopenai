# MockOpenAI

A local mock server for OpenAI-compatible APIs — deterministic responses and
per-request failure simulation for any Ruby application.

MockOpenAI lets you test any Ruby app that calls an LLM **without hitting real
APIs**. It works with Rails, Sinatra, CLI tools, background jobs, or plain Ruby
scripts. It gives you:

- Deterministic responses
- Per-request matching (exact, substring, regex)
- Realistic failure mode simulation
- Zero token costs
- Fast, reliable CI
- A clean RSpec metadata API

All without modifying your application code or wrapping your OpenAI client.

---

## Features

- **Drop-in replacement** for `/v1/chat/completions`
- **Unified rule engine** for success + failure behavior
- **Per-request matching** (exact, substring, regex)
- **Simulate real LLM failures**, including:
  - Timeouts
  - Rate limits
  - Malformed JSON
  - Internal server errors
  - Truncated streaming
- **RSpec metadata API** (works with Rails, Sinatra, or plain Ruby)
- **Stateless local mock server** for end-to-end and system tests
- **File-based shared state** (no client wrapping, no monkey-patching)
- **Deterministic tests** for CI/CD

---

## Installation

Add to your Gemfile:

```ruby
group :test do
  gem "mock_openai"
end
```

Install:

```
bundle install
```

---

## Usage Patterns

MockOpenAI supports two modes depending on your test type:

### In-process (unit and integration tests)

For RSpec tests that call your Ruby service objects or controllers directly, no
server process is needed. The mock handler runs inside the test process via
rack-test:

```ruby
# spec/rails_helper.rb
require "mock_openai/rspec"
```

```ruby
# spec/services/my_service_spec.rb
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

State is shared via a JSON file that both the test and the Rack handler
read/write within the same process. No ports, no sockets.

### Standalone server (system and end-to-end tests)

For Capybara or Playwright tests that drive a real Rails server process, the
app and tests run in separate processes. Start the mock server in a terminal:

```
mock-openai start
```

Configure your OpenAI client to point at it in `config/environments/test.rb`:

```ruby
OpenAI.configure do |c|
  c.api_base = "http://localhost:4000/v1"
end
```

Tests still control behavior via `MockOpenAI.set_responses` — it writes to the
same shared state file that the server reads on every request.

---

## Examples

### Simple canned response

```ruby
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Hello", response: "Hi!" }
  ])

  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

### Multi-step conversation

Rules are matched in order (first match wins) using exact, substring, or regex
matching against the last user message.

```ruby
it "handles a multi-step conversation", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Hello", response: "Hi!" },
    { match: "^Order.*", response: "Order shipped." },
    { match: "Thanks", response: "You're welcome!" }
  ])

  result = MyService.complex_flow

  expect(result[:greeting]).to eq("Hi!")
  expect(result[:order]).to eq("Order shipped.")
  expect(result[:closing]).to eq("You're welcome!")
end
```

### Failure modes (per request)

Failures are specified per-rule, not per-test, so you can mix success and
failure in a single test run:

```ruby
it "handles mixed outcomes", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Step 1", response: "OK" },
    { match: "Step 2", failure_mode: :timeout },
    { match: "Step 3", response: "Done" }
  ])

  expect(MyService.step1).to eq("OK")
  expect { MyService.step2 }.to raise_error(Timeout::Error)
  expect(MyService.step3).to eq("Done")
end
```

Available failure modes:

| Symbol | Behavior |
|--------|----------|
| `:timeout` | Sleeps for configured duration (simulates slow/unresponsive LLM) |
| `:rate_limit` | Returns HTTP 429 with rate limit error body |
| `:malformed_json` | Returns syntactically invalid JSON |
| `:internal_error` | Returns HTTP 500 with server error body |
| `:truncated_stream` | Sends partial SSE chunks then closes connection |

### Templates

Dynamic responses using template variables:

```ruby
MockOpenAI.set_responses([
  { match: ".*", template: "Mock reply to: {{last_user_message}}" }
])
```

Supported variables: `{{last_user_message}}`, `{{system_message}}`, `{{model}}`

---

## RSpec Metadata Reference

| Tag | Behavior |
|-----|----------|
| `:mock_openai` | Enables MockOpenAI; resets state before/after the example |
| `:mock_openai_timeout` | Shortcut: all requests return timeout |
| `:mock_openai_rate_limit` | Shortcut: all requests return 429 |
| `:mock_openai_malformed_json` | Shortcut: all requests return malformed JSON |
| `:mock_openai_internal_error` | Shortcut: all requests return 500 |
| `:mock_openai_truncated_stream` | Shortcut: all requests return truncated stream |

The shortcut tags are equivalent to `set_responses([{ match: ".*", failure_mode: :... }])`.

State is automatically reset after each tagged test — no manual cleanup needed.

---

## Public API

```ruby
MockOpenAI.set_responses([...])          # Set ordered rules for this test
MockOpenAI.set_failure_mode(:timeout)    # Convenience: apply one failure to all requests
MockOpenAI.reset!                        # Clear all rules (called automatically between tests)
```

---

## CLI Reference

```
mock-openai start              # Start server on localhost:4000
mock-openai start --port=4001  # Use a different port
mock-openai init               # Generate a sample mock_openai.yml config
mock-openai check              # Validate config
```

---

## Configuration

Optional `mock_openai.yml` in your project root:

```yaml
default_response: "Hello from MockOpenAI!"
timeout_seconds: 5
```

---

## How It Works

1. Your Rails tests write rules to `tmp/mock_openai_state.json` via `MockOpenAI.set_responses`
2. The mock server reads this file on every request (stateless)
3. It extracts the last user message from the request body
4. It finds the first matching rule (exact → regex → substring)
5. It applies the rule: failure mode, static response, or template
6. If no rule matches, it returns the configured default response

The server stores no internal state. All behavior is driven by the shared state
file, making tests fully deterministic and isolated.

---

## Roadmap

- Embeddings endpoint support
- Function/tool calling simulation
- Multi-model support (Anthropic, Gemini, etc.)
- Parallel test support (per-process state files)
- Hosted mock server for teams
- CI integration helpers

---

## Contributing

PRs welcome. Open an issue to discuss new failure modes, matchers, or integrations.

---

## License

MIT
