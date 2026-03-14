---
title: Standalone Server
parent: Usage
nav_order: 2
---

# Standalone Server

For Capybara or Playwright tests that drive a real Rails server process,
the app and tests run in separate processes. Start the mock server in a
terminal:

```
mock-openai start
```

Configure your OpenAI client to point at it in `config/environments/test.rb`:

```ruby
OpenAI.configure do |c|
  c.api_base = "http://localhost:4000/v1"
end
```

Tests still control behavior via `MockOpenAI.set_responses` — it writes to
the same shared state file that the server reads on every request.
