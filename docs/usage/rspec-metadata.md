---
title: RSpec Metadata
parent: Usage
nav_order: 4
---

# RSpec Metadata

Add `require "mock_openai/rspec"` to `spec/rails_helper.rb` once. Metadata tags then control mock state
automatically — no manual `before`/`after` hooks needed.

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

## Starting the test server

The `:mock_openai` tag resets state between tests but does not start a server.
If your code makes **outbound HTTP connections** to an LLM API — CLI tools,
Rails apps calling the API in integration tests, background jobs — you must
start a server process and point your LLM client at it.

Call `MockOpenAI.start_test_server!` once at the top of `spec/rails_helper.rb`
and configure your LLM client to use `MockOpenAI.server_url`:

```ruby
# spec/rails_helper.rb
require "mock_openai/rspec"

MockOpenAI.start_test_server!

RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", "test-key")
  config.anthropic_api_base = MockOpenAI.server_url
end
```

`start_test_server!` is idempotent — calling it more than once is safe. It
blocks until the server is accepting connections.

`start_test_server!` is **not** needed when testing a Rack app directly via
`rack-test` (e.g. requests going through the Rack stack in-process without
opening a TCP connection).
