# MockOpenAI Gem Demo

*2026-03-14T15:11:14Z by Showboat 0.6.0*
<!-- showboat-id: 3619c7c1-bb12-4774-8114-e51b069c69d5 -->

MockOpenAI is a local Rack-based mock server gem for OpenAI-compatible APIs. It
gives your test suite deterministic, per-test control over mock server
responses — no monkey-patching, no network, no separate process needed for
integration tests.

All behaviour is encoded in a shared JSON state file. Tests write rules via
`MockOpenAI.set_responses`; the Rack handler reads them on every request.
Communication is pure file I/O.

## 1. CLI

The `mock-openai` binary ships with three commands: `check`, `init`, and `start`.

**`check`** — print the resolved configuration (reads `mock_openai.yml` if present, otherwise shows defaults):

```bash
bundle exec ruby bin/mock-openai check
```

```output
MockOpenAI configuration:
  port:             4000
  timeout_seconds:  5
  default_response: Mock response from MockOpenAI
  state_file:       tmp/mock_openai_state.json
```

**`init`** — scaffold a `mock_openai.yml` config file with commented-out defaults:

```bash
rm -f mock_openai.yml && bundle exec ruby bin/mock-openai init && echo '---' && cat mock_openai.yml && rm mock_openai.yml
```

```output
Created mock_openai.yml
---
# MockOpenAI configuration
# port: 4000
# timeout_seconds: 5
# default_response: "Mock response from MockOpenAI"
```

**`start`** — boot the Rack/WEBrick server on the configured port (binds to
`127.0.0.1` by default, accepts `--port=N`). Not shown here since it blocks;
use it to run the mock as a standalone service alongside an app under test.

## 2. Public Ruby API

Three class methods cover the full test lifecycle ([`docs/demo_api.rb`](demo_api.rb)):

```ruby
# Set one or more rules — first match wins
MockOpenAI.set_responses([
  { match: "hello",   response: "Hi there!" },          # exact / substring / regex
  { match: "^Order",  response: "Your order is on its way." },
  { match: ".*",      response: "I do not understand that." }  # catch-all
])

MockOpenAI.set_failure_mode(:rate_limit)   # all requests → 429
MockOpenAI.current_failure_mode            # => :rate_limit
MockOpenAI.reset!                          # clear all rules
```

```bash
bundle exec ruby docs/demo_api.rb
```

```output
Rules written: 3
  hello        => Hi there!
  ^Order       => Your order is on its way.
  .*           => I don't understand that.

Current failure mode: rate_limit
After reset — rules: 0, mode: nil
```

## 3. HTTP Handler

`POST /v1/chat/completions` speaks the OpenAI wire format. The handler can be
driven directly with rack-test — no server process needed
([`docs/demo_http.rb`](demo_http.rb)):

```ruby
app     = MockOpenAI::Router.new
session = Rack::Test::Session.new(Rack::MockSession.new(app))

MockOpenAI.set_responses([
  { match: "^summarize", template: "Summary of: {{last_user_message}}" },
  { match: ".*",         response: "Fallback answer." }
])

session.post("/v1/chat/completions",
  { model: "gpt-4", messages: [{ role: "user", content: "summarize this" }] }.to_json,
  "CONTENT_TYPE" => "application/json")

JSON.parse(session.last_response.body).dig("choices", 0, "message", "content")
# => "Summary of: summarize this"
```

```bash
bundle exec ruby docs/demo_http.rb
```

```output
=== Default response (no rules) ===
Status: 200
Reply:  Mock response from MockOpenAI

=== Pattern-matched responses ===
  hello there                      => Hey! How can I help?
  summarize this document please   => Summary of: summarize this document please
  something else entirely          => Fallback answer.

=== Failure modes ===
rate_limit     → HTTP 429  rate_limit_exceeded
internal_error → HTTP 500
malformed_json → HTTP 200  valid JSON? no

=== Error handling ===
Bad JSON body  → HTTP 400  invalid_request_error
Unknown route  → HTTP 404
```

## 4. RSpec Metadata Integration

Add `require "mock_openai/rspec"` to `spec_helper.rb` once. Metadata tags then
control mock state automatically — no manual `before`/`after` hooks needed
([`docs/demo_rspec_spec.rb`](demo_rspec_spec.rb)):

```ruby
# :mock_openai — resets state before each example
describe "my AI feature", :mock_openai do
  before { MockOpenAI.set_responses([{ match: "ping", response: "pong" }]) }

  it "returns the matched response" do
    # state is clean at the start; rules set above are in effect
  end
end

# Shortcut tags — reset + set failure mode in one step
it "handles rate limiting gracefully", :mock_openai_rate_limit do
  # all requests in this example return HTTP 429
end

# Available shortcut tags:
# :mock_openai_rate_limit, :mock_openai_internal_error,
# :mock_openai_malformed_json, :mock_openai_timeout,
# :mock_openai_truncated_stream
```

```bash
bundle exec rspec docs/demo_rspec_spec.rb --format documentation --no-color
```

```output

MockOpenAI RSpec integration demo
  simulates rate limiting
  simulates server errors
  deterministic responses
    matches exact patterns
    falls back to catch-all
  state isolation between examples
    starts with no rules (state was reset by :mock_openai before hook)

Finished in 0.00679 seconds (files took 0.07208 seconds to load)
5 examples, 0 failures

```

## 5. Full Test Suite

71 examples covering every class — Config, State, Matcher, ResponseBuilder,
TemplateRenderer, all five FailureMode classes, ChatCompletions handler,
Router, Server, CLI, RSpec metadata, and the public API.

```bash
bundle exec rspec --format progress --no-color
```

```output
.......................................................................

Finished in 0.03361 seconds (files took 0.06951 seconds to load)
71 examples, 0 failures

```
