# MVP Feature List

**Summary:** A local, Rails-friendly mock OpenAI server that provides
deterministic responses and configurable failure modes for fast, reliable,
cost-free testing.

**Target niche:** Rails developers
**Deployment model:** Local-first
**UVPs:**
- A: Drop-in OpenAI mock server for testing & CI
- B: Simulate LLM failures your tests never catch

---

## 1. Core Mock Server

### 1.1 Chat Completions Endpoint

- `POST /v1/chat/completions` — accepts the same request body as the OpenAI API
- Supports: `model`, `messages`, `temperature`, `max_tokens`, `n`, `stream` (stubbed)
- Returns deterministic, OpenAI-compatible JSON response

### 1.2 Rule-Based Responses

Shared state contains an ordered list of rules. Each request is matched against rules in order; first match wins.

Each rule supports:

| Field          | Description                                                                     |
| -------------- | ------------------------------------------------------------------------------- |
| `match`        | String (exact, substring) or regex pattern matched against last user message    |
| `response`     | Static response text                                                            |
| `failure_mode` | Symbol — applies a failure behavior                                             |
| `template`     | Template string with `{{last_user_message}}`, `{{system_message}}`, `{{model}}` |

If no rule matches, falls back to global `response_template`, then `default_response`.

### 1.3 Configuration File

Optional `mock_openai.yml`:

```yaml
default_response: "Hello from MockOpenAI!"
timeout_seconds: 5
```

---

## 2. Failure Mode Simulation

Each failure mode is a named class invocable per-rule. Failure mode overrides response when both are specified.

| Mode                | Behavior                                                |
| ------------------- | ------------------------------------------------------- |
| `:timeout`          | Sleeps `timeout_seconds` (default: 5) before responding |
| `:rate_limit`       | Returns HTTP 429 with OpenAI-format error body          |
| `:malformed_json`   | Returns syntactically invalid JSON with HTTP 200        |
| `:internal_error`   | Returns HTTP 500 with OpenAI-format error body          |
| `:truncated_stream` | Sends partial SSE chunks then closes connection         |

---

## 3. Shared State

**File:** `tmp/mock_openai_state.json`

```json
{
  "rules": [
    { "match": "Hello", "response": "Hi!" },
    { "match": "^Order.*", "failure_mode": "internal_error" }
  ],
  "response_template": null,
  "default_response": "Mock response",
  "metadata": {}
}
```

Written by the Rails test suite, read by the mock server on every request. Server stores no internal state.

---

## 4. Rails / RSpec Integration

### 4.1 RSpec Metadata Tags

```ruby
# Generic tag — clean slate, auto-reset
it "...", :mock_openai do
  MockOpenAI.set_responses([...])
end

# Shortcut tags — apply a single failure mode to all requests
it "...", :mock_openai_timeout do; end
it "...", :mock_openai_rate_limit do; end
it "...", :mock_openai_malformed_json do; end
it "...", :mock_openai_internal_error do; end
it "...", :mock_openai_truncated_stream do; end
```

State resets automatically after each tagged test.

### 4.2 Public API

```ruby
MockOpenAI.set_responses([...])       # Write rules to shared state
MockOpenAI.set_failure_mode(:timeout) # Shortcut: one failure for all requests
MockOpenAI.reset!                     # Clear shared state
```

### 4.3 OpenAI Client Configuration

No client wrapping. Users redirect the base URL in test mode:

```ruby
# config/environments/test.rb
OpenAI.configure { |c| c.api_base = "http://localhost:4000/v1" }
```

Works with the `openai` gem, `ruby_llm`, or any HTTP client — no gem-specific integration needed.

---

## 5. CLI

```
mock-openai start              # Start server on localhost:4000
mock-openai start --port=4001  # Custom port
mock-openai init               # Generate sample mock_openai.yml
mock-openai check              # Validate config and print status
```

Server prints on startup:

```
MockOpenAI server running on http://localhost:4000
Watching shared state: tmp/mock_openai_state.json
```

---

## 6. Developer Experience

- Requests are logged: endpoint, matched rule, applied failure mode
- Missing/corrupted state file is handled gracefully (logs warning, uses defaults)
- README with quickstart, examples, and RSpec reference
- `require "mock_openai/rspec"` loads all RSpec hooks in one line

---

## 7. Not in MVP

The following are intentionally deferred:

- Hosted/SaaS mock server
- Multi-model support (Anthropic, DeepSeek, etc.)
- Tool calling / function calling simulation
- Embeddings, vision, audio endpoints
- Web UI / dashboard
- Team features / analytics
- CI cloud integration
- Parallel test support (per-process state files)

