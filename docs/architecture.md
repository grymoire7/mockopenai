# MockOpenAI Architecture

This document captures the key architectural decisions made during the design phase.

---

## Problem Statement

Developers integrating with OpenAI-compatible APIs struggle with:

- Expensive test runs (real API calls burn tokens)
- Slow, non-deterministic tests
- Untested failure modes (VCR-style tools only capture happy paths)
- Flaky CI pipelines
- No way to simulate: timeouts, rate limits, malformed JSON, truncated streaming

Generic mock API tools (Mockaroo, Beeceptor, etc.) return static JSON but cannot simulate LLM-specific behaviors like streaming, variable latency, or realistic error shapes.

---

## Core Design Goals

- **No client wrapping** — works with any OpenAI-compatible Ruby client (`openai` gem, `ruby_llm`, Faraday wrappers, etc.)
- **No monkey-patching**
- **No prompt pollution** — test config never leaks into the prompt
- **No server restarts** — failure modes change per-test without restarting
- **Rails-native** — feels like RSpec, VCR, WebMock, and FactoryBot
- **Stateless server** — easy to reason about, easy to extend

---

## Deployment Model: Local-First

The mock server runs locally (not hosted) for the following reasons:

- Rails developers are accustomed to local tools (VCR, WebMock, FactoryBot)
- Tests must be fast, offline, and isolated — a hosted service introduces network latency and external dependencies
- The UVPs (drop-in testing + failure simulation) are test-centric and require determinism
- Local = free, which removes any barrier to adoption

Future: hosted version for teams (shared mock datasets, CI integrations, analytics).

---

## Shared State: File-Based JSON

**Decision: `tmp/mock_openai_state.json`**

The mock server is stateless — it reads this file on every request. The Rails test suite writes to it before each test and resets it after.

### Why not `Rails.cache`?

- `Rails.cache` defaults to `:null_store` in test mode — writes are no-ops
- `MemoryStore` is not shared across processes (tests run in one process, server in another)
- Cache stores behave inconsistently across environments
- File-based state is universal, cross-process, trivially debuggable, and language-agnostic (important for future Node/Python support)

### Why not Redis?

Overkill for MVP. Adds an external dependency. File I/O on a tiny JSON file is microseconds.

### Future: Parallel Test Support

Use per-process state files when parallel tests are needed:

```
tmp/mock_openai_state_<PID>.json
```

---

## Unified Rule Engine

All behavior — success responses and failure modes — is expressed as an ordered list of **rules**:

```json
{
  "rules": [
    { "match": "Hello",    "response": "Hi!" },
    { "match": "^Order.*", "response": "Order shipped." },
    { "match": "Oops",     "failure_mode": "internal_error" }
  ],
  "default_response": "Mock response"
}
```

This unified model was chosen over separate `set_failure_mode` / `set_response` APIs because:

- One mental model for developers
- Per-request control over both success and failure
- Easy to express complex multi-step flows with mixed outcomes
- Extensible without API changes (add `delay:`, `stream:`, etc. to rules later)

`set_failure_mode(:timeout)` is kept as a convenience shortcut that expands to `{ match: ".*", failure_mode: :timeout }`.

---

## Per-Request Matching Algorithm

Match target: **last user message** from the request body.

Rules are evaluated top-to-bottom; first match wins.

For each rule, matching is attempted in this order:

1. **Exact match** — `rule["match"] == last_user_message`
2. **Regex match** — if pattern looks like a regex (starts with `^`, ends with `$`, or contains `.*`)
3. **Substring match** — `last_user_message.include?(rule["match"])`

When a rule matches, priority for determining response:

1. `failure_mode` (if present, overrides everything)
2. `response` (static string)
3. `template` (rendered with `{{last_user_message}}`, `{{system_message}}`, `{{model}}`)

If no rule matches: use `response_template` (global), then `default_response`.

---

## RSpec Integration

The primary developer interface is **RSpec metadata tags** — no application code changes required.

```ruby
it "handles timeouts", :mock_openai_timeout do
  expect { MyService.call_ai }.to raise_error(Timeout::Error)
end

it "handles a complex flow", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Step 1", response: "OK" },
    { match: "Step 2", failure_mode: :timeout }
  ])
  # ...
end
```

State is automatically reset after each `:mock_openai*`-tagged test.

This approach was chosen over:
- **Header injection** — requires wrapping every OpenAI client library (fragile, maintenance burden)
- **Prompt embedding** (`#MockOpenAI failure_mode: timeout`) — pollutes prompts, risks leaking into production, no clean separation of concerns

---

## Failure Mode Classes

Each failure mode is a class under `MockOpenAI::FailureModes` inheriting from `Base`:

```ruby
def apply(request:, response:)
  # returns a Rack response [status, headers, body]
  # or a symbol: :timeout, :stream_truncated
end
```

MVP failure modes:
- `Timeout` — sleeps N seconds (configurable)
- `RateLimit` — returns HTTP 429 with OpenAI-shaped error body
- `MalformedJson` — returns syntactically broken JSON
- `InternalError` — returns HTTP 500 with OpenAI-shaped error body
- `TruncatedStream` — sends partial SSE chunks then closes connection

New failure modes can be added without touching server or routing code.

---

## Gem Structure

```
mock_openai/
├── bin/
│   └── mock-openai              # CLI entrypoint
├── lib/
│   ├── mock_openai.rb           # Public API: set_responses, reset!, etc.
│   └── mock_openai/
│       ├── version.rb
│       ├── config.rb            # Load mock_openai.yml
│       ├── state.rb             # Read/write tmp/mock_openai_state.json
│       ├── server.rb            # Rack/Sinatra app, startup behavior
│       ├── router.rb            # Route POST /v1/chat/completions
│       ├── handlers/
│       │   ├── chat_completions.rb   # Parse request, run matching, build response
│       │   └── errors.rb
│       ├── failure_modes/
│       │   ├── base.rb
│       │   ├── timeout.rb
│       │   ├── rate_limit.rb
│       │   ├── malformed_json.rb
│       │   ├── internal_error.rb
│       │   └── truncated_stream.rb
│       └── rspec/
│           └── metadata.rb      # RSpec.configure hooks
└── mock_openai.yml.example
```

---

## Explicitly Out of Scope (MVP)

- Hosted/SaaS mock server
- Multi-model support (Anthropic, DeepSeek, etc.)
- Tool calling / function calling simulation
- Embeddings, vision, audio endpoints
- Web UI
- Team features / analytics
- CI cloud integration

These are post-traction additions.
