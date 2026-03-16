---
title: Standalone Server
parent: Usage
nav_order: 2
---

# Standalone Server

Use the standalone server when your app and tests run in **separate processes** —
for example, Capybara or Playwright tests that drive a full Rails stack over a
real HTTP connection. Start the mock server in a terminal before running your
test suite:

```
mock-openai start
```

Configure your LLM client in `config/environments/test.rb`:

```ruby
OpenAI.configure do |c|
  c.api_base = "http://localhost:4000/v1"
end
```

Tests still control behavior via `MockOpenAI.set_responses` — it writes to
the same shared state file that the server reads on every request.

## Unit and integration tests (same-process)

If your app and tests run in the **same process** — the common case for Rails
unit/integration tests, CLI tools, and plain Ruby projects — use
`MockOpenAI.start_test_server!` in `test_helper.rb` instead. See the
[Minitest](minitest.md) guide.
