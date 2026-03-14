# MockOpenAI Design Document

This document describes the technical design of the `mock_openai` gem. It is intended as a guide for implementation, covering module responsibilities, data flows, class interfaces, and key behavioral contracts.

For architectural decisions and their rationale, see [architecture.md](architecture.md).
For the MVP feature scope, see [mvp.md](mvp.md).

---

## Overview

MockOpenAI consists of two cooperating components:

1. **The mock server** — a local HTTP server that handles OpenAI-compatible API requests
2. **The test helper** — a Ruby module that writes shared state and provides the RSpec integration

These components communicate through a shared state file (`tmp/mock_openai_state.json`). The server is stateless; all per-test behavior is driven entirely by what the test helper writes to that file.

```
┌─────────────────────────────────────────────────┐
│  Rails test process                             │
│                                                 │
│   RSpec ──► MockOpenAI.set_responses([...])     │
│                     │                           │
│                     ▼                           │
│           tmp/mock_openai_state.json            │
│                     │                           │
│   Application ──► OpenAI client                 │
│                     │ HTTP POST /v1/chat/...     │
└─────────────────────┼───────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  Mock server process (localhost:4000)           │
│                                                 │
│   Router ──► Handler ──► read state file        │
│                              │                  │
│                              ▼                  │
│                       match rules               │
│                              │                  │
│                              ▼                  │
│                       return response           │
└─────────────────────────────────────────────────┘
```

---

## Module Breakdown

### `MockOpenAI` (top-level module)

Public API used by tests. Delegates to `State` for persistence.

```ruby
module MockOpenAI
  # Write an ordered list of rules to shared state.
  # Each rule is a hash with keys: match:, response:, failure_mode:, template:
  def self.set_responses(rules)

  # Convenience shortcut. Equivalent to:
  #   set_responses([{ match: ".*", failure_mode: mode }])
  def self.set_failure_mode(mode)

  # Clear all rules and reset shared state to defaults.
  def self.reset!

  # Read the current failure mode for the first catch-all rule, if any.
  # (Used internally by RSpec shortcut metadata hooks.)
  def self.current_failure_mode
end
```

---

### `MockOpenAI::Config`

Loads `mock_openai.yml` (if present) and provides defaults.

```ruby
module MockOpenAI
  class Config
    attr_reader :port             # default: 4000
    attr_reader :timeout_seconds  # default: 5
    attr_reader :default_response # default: "Mock response from MockOpenAI"
    attr_reader :state_file       # default: "tmp/mock_openai_state.json"

    def self.load(path = "mock_openai.yml")
  end
end
```

---

### `MockOpenAI::State`

Owns all reads and writes to the shared state file. The server and the test helper both use this class.

```ruby
module MockOpenAI
  class State
    STATE_FILE = "tmp/mock_openai_state.json"

    EMPTY = {
      "rules"             => [],
      "response_template" => nil,
      "default_response"  => nil,
      "metadata"          => {}
    }.freeze

    # Write rules array to state file.
    def self.write(rules:, response_template: nil, default_response: nil)

    # Read and parse state file. Returns EMPTY if file is missing or corrupt.
    def self.read

    # Overwrite state file with EMPTY.
    def self.reset!
  end
end
```

**Error handling:** If the state file is missing or contains invalid JSON, `read` logs a warning and returns `EMPTY`. The server never raises on a missing state file.

---

### `MockOpenAI::Server`

Starts the Rack/Sinatra HTTP server. Responsible for startup behavior only; all request logic lives in `Router` and `Handler`.

```ruby
module MockOpenAI
  class Server
    def self.start(port: MockOpenAI.config.port)
    # - Ensures tmp/ directory exists
    # - Initializes state file if missing
    # - Starts Rack server on localhost:port
    # - Prints startup message
  end
end
```

The server binds to `127.0.0.1` only. It does not bind to `0.0.0.0`.

---

### `MockOpenAI::Router`

A minimal Rack (or Sinatra) app that maps HTTP endpoints to handlers.

**MVP routes:**

| Method | Path | Handler |
|--------|------|---------|
| `POST` | `/v1/chat/completions` | `Handlers::ChatCompletions` |

All other paths return HTTP 404 with a JSON error body.

---

### `MockOpenAI::Handlers::ChatCompletions`

Core request handler. Orchestrates parsing, matching, failure mode application, and response construction.

**Request flow:**

```
1. Parse JSON request body
   └─ On parse failure: return HTTP 400

2. Extract last user message
   request["messages"].reverse.find { |m| m["role"] == "user" }&.dig("content")

3. Load shared state (MockOpenAI::State.read)

4. Find first matching rule (MockOpenAI::Matcher.match)

5a. Rule has failure_mode:
    └─ Delegate to FailureModes::<Mode>.new.apply(request:, response:)

5b. Rule has response:
    └─ Build success response with that text

5c. Rule has template:
    └─ Render template, build success response

5d. No rule matched:
    └─ Use state["response_template"] if present, else state["default_response"]
       (falling back to MockOpenAI.config.default_response)

6. Log: method, path, matched rule index or "default", applied failure mode (if any)

7. Return Rack response
```

---

### `MockOpenAI::Matcher`

Encapsulates the rule-matching algorithm. Stateless and pure.

```ruby
module MockOpenAI
  class Matcher
    # Returns the first rule that matches last_user_message, or nil.
    def self.match(rules, last_user_message)
  end
end
```

**Matching order for each rule** (the first to succeed wins the rule; then rules are checked top-to-bottom):

1. **Exact match** — `rule["match"] == last_user_message`
2. **Regex match** — if the pattern is regex-like, `Regexp.new(rule["match"]).match?(last_user_message)`
3. **Substring match** — `last_user_message.include?(rule["match"])`

**Regex detection heuristic:**

```ruby
def self.regex_like?(pattern)
  pattern.start_with?("^") ||
    pattern.end_with?("$") ||
    pattern.include?(".*") ||
    pattern.include?("(") ||
    pattern.include?("[")
end
```

If `Regexp.new(pattern)` raises, it is treated as a plain substring match (log a warning).

---

### `MockOpenAI::ResponseBuilder`

Constructs a valid OpenAI-compatible `chat.completion` response hash.

```ruby
module MockOpenAI
  class ResponseBuilder
    # Returns a Hash (not JSON string) representing a chat.completion response.
    def self.build(content:, model: "mock-gpt-4", request_id: nil)
  end

  # Example output:
  # {
  #   "id" => "mock-chatcmpl-abc123",
  #   "object" => "chat.completion",
  #   "created" => 1234567890,
  #   "model" => "mock-gpt-4",
  #   "choices" => [
  #     {
  #       "index" => 0,
  #       "message" => { "role" => "assistant", "content" => content },
  #       "finish_reason" => "stop"
  #     }
  #   ],
  #   "usage" => { "prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0 }
  # }
end
```

---

### `MockOpenAI::TemplateRenderer`

Renders template strings by substituting variables.

```ruby
module MockOpenAI
  class TemplateRenderer
    VARIABLES = {
      "{{last_user_message}}" => ->(ctx) { ctx[:last_user_message] },
      "{{system_message}}"    => ->(ctx) { ctx[:system_message] },
      "{{model}}"             => ->(ctx) { ctx[:model] }
    }.freeze

    def self.render(template, context)
    # context = { last_user_message:, system_message:, model: }
  end
end
```

Unrecognized variables are left as-is (no error raised).

---

### `MockOpenAI::FailureModes`

#### Base class

```ruby
module MockOpenAI
  module FailureModes
    class Base
      # Returns one of:
      #   - A Rack response: [status, headers, body_array]
      #   - The symbol :timeout
      #   - The symbol :stream_truncated
      def apply(request:, response:)
        raise NotImplementedError
      end
    end
  end
end
```

#### Timeout

```ruby
class Timeout < Base
  def apply(request:, response:)
    :timeout
    # Server interprets :timeout as: sleep(MockOpenAI.config.timeout_seconds)
    # then closes the connection without sending a response body.
  end
end
```

#### RateLimit

```ruby
class RateLimit < Base
  def apply(request:, response:)
    [429, { "Content-Type" => "application/json" }, [body.to_json]]
    # body = { "error" => { "type" => "rate_limit_error",
    #                       "message" => "Rate limit exceeded",
    #                       "code" => "rate_limit_exceeded" } }
  end
end
```

#### MalformedJson

```ruby
class MalformedJson < Base
  def apply(request:, response:)
    [200, { "Content-Type" => "application/json" }, ['{ "choices": [ ']]
    # Intentionally truncated — causes JSON::ParserError in the client
  end
end
```

#### InternalError

```ruby
class InternalError < Base
  def apply(request:, response:)
    [500, { "Content-Type" => "application/json" }, [body.to_json]]
    # body = { "error" => { "type" => "server_error",
    #                       "message" => "Internal server error" } }
  end
end
```

#### TruncatedStream

```ruby
class TruncatedStream < Base
  def apply(request:, response:)
    :stream_truncated
    # Server interprets :stream_truncated as:
    # - Set Content-Type: text/event-stream
    # - Send 2-3 partial SSE data chunks
    # - Close connection without sending [DONE]
  end
end
```

#### Failure mode resolution

```ruby
module MockOpenAI
  module FailureModes
    REGISTRY = {
      "timeout"          => Timeout,
      "rate_limit"       => RateLimit,
      "malformed_json"   => MalformedJson,
      "internal_error"   => InternalError,
      "truncated_stream" => TruncatedStream
    }.freeze

    def self.apply(mode, request:, response:)
      klass = REGISTRY.fetch(mode.to_s) { raise ArgumentError, "Unknown failure mode: #{mode}" }
      klass.new.apply(request: request, response: response)
    end
  end
end
```

---

### `MockOpenAI::RSpec::Metadata`

Loaded via `require "mock_openai/rspec"`. Registers RSpec hooks.

```ruby
RSpec.configure do |config|
  # Generic tag: reset state before test
  config.before(:each, :mock_openai) do
    MockOpenAI.reset!
  end

  # Shortcut failure mode tags
  {
    mock_openai_timeout:          :timeout,
    mock_openai_rate_limit:       :rate_limit,
    mock_openai_malformed_json:   :malformed_json,
    mock_openai_internal_error:   :internal_error,
    mock_openai_truncated_stream: :truncated_stream
  }.each do |tag, mode|
    config.before(:each, tag) do
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

---

### `MockOpenAI::CLI`

Parsed by `bin/mock-openai`. Uses `OptionParser` or similar.

**Commands:**

- `start [--port=N]` — start the server
- `init` — write a sample `mock_openai.yml` to the current directory (fails if file already exists)
- `check` — validate `mock_openai.yml` and print resolved config

---

## Shared State Schema

**File:** `tmp/mock_openai_state.json`

```json
{
  "rules": [
    {
      "match": "string or regex pattern",
      "response": "static response text",
      "failure_mode": "timeout|rate_limit|malformed_json|internal_error|truncated_stream",
      "template": "template string with {{variables}}"
    }
  ],
  "response_template": null,
  "default_response": null,
  "metadata": {}
}
```

- `rules` — ordered; first match wins
- Each rule may have `response` OR `failure_mode` OR `template`; if multiple are set, `failure_mode` takes precedence
- `response_template` — global template applied when no rule matches
- `default_response` — plain text fallback when no rule matches and no global template is set
- `metadata` — reserved for future use
- `null` values are equivalent to absent keys

---

## Logging

Every request produces a single log line to stdout:

```
[MockOpenAI] POST /v1/chat/completions | rule=2 | mode=rate_limit
[MockOpenAI] POST /v1/chat/completions | rule=none | mode=none
[MockOpenAI] POST /v1/chat/completions | rule=0 | mode=none
```

Format: `[MockOpenAI] <METHOD> <PATH> | rule=<index|none> | mode=<mode|none>`

---

## CLI Startup Output

```
MockOpenAI v0.1.0 started
  Listening on: http://localhost:4000
  State file:   tmp/mock_openai_state.json
  Config:       mock_openai.yml (not found, using defaults)
```

---

## Error Responses

All error responses (4xx, 5xx) use this shape to match the OpenAI API:

```json
{
  "error": {
    "type": "...",
    "message": "...",
    "code": "..."
  }
}
```

| Situation | Status | `type` |
|-----------|--------|--------|
| Invalid JSON in request body | 400 | `invalid_request_error` |
| Unknown route | 404 | `invalid_request_error` |
| Rate limit failure mode | 429 | `rate_limit_error` |
| Internal error failure mode | 500 | `server_error` |

---

## File Layout

```
mock_openai/
├── bin/
│   └── mock-openai
├── lib/
│   ├── mock_openai.rb
│   └── mock_openai/
│       ├── version.rb
│       ├── config.rb
│       ├── state.rb
│       ├── server.rb
│       ├── router.rb
│       ├── matcher.rb
│       ├── response_builder.rb
│       ├── template_renderer.rb
│       ├── handlers/
│       │   └── chat_completions.rb
│       ├── failure_modes/
│       │   ├── base.rb
│       │   ├── timeout.rb
│       │   ├── rate_limit.rb
│       │   ├── malformed_json.rb
│       │   ├── internal_error.rb
│       │   └── truncated_stream.rb
│       ├── rspec/
│       │   └── metadata.rb
│       └── cli.rb
├── mock_openai.gemspec
├── Gemfile
└── README.md
```
