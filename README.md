<p align="center">
  <img src="docs/assets/img/mockopenai_logo_medium.png" alt="MockOpenAI logo" />
</p>

# MockOpenAI

[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://grymoire7.github.io/mockopenai)
![Tests](https://github.com/grymoire7/mockopenai/actions/workflows/ruby.yml/badge.svg?branch=main)
![Ruby Version](https://img.shields.io/badge/Ruby-%3E%3D%203.0-green?logo=Ruby&logoColor=red&label=Ruby%20version&color=green)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/grymoire7/mockopenai/blob/main/LICENSE)

A local mock server for OpenAI-compatible and Anthropic APIs with deterministic responses
and per-request failure simulation for any Ruby application.

MockOpenAI lets you test any Ruby app that calls an LLM **without hitting real
APIs**, spending real money, or waiting on rate limits. It supports the OpenAI
Chat Completions API (`POST /v1/chat/completions`) and the Anthropic Messages
API (`POST /v1/messages`). Works with Rails, Sinatra, CLI tools, background
jobs, or plain Ruby scripts.

---

## Why MockOpenAI?

- **No API keys needed**: zero token costs, zero network calls in CI
- **Deterministic**: control exactly what the LLM "says" for each request
- **Per-request failure modes**: simulate timeouts, rate limits, malformed JSON, and more
- **No app changes**: no monkey-patching, no client wrapping, no test doubles
- **Fast CI**: tests run at local speed, not API speed
- **OpenAI + Anthropic**: supports `POST /v1/chat/completions` and `POST /v1/messages`

---

## Installation

```ruby
# Gemfile
group :test do
  gem "mock_openai"
end
```

```
bundle install
```

---

## Quick Start

**RSpec:**

```ruby
# spec/rails_helper.rb
require "mock_openai/rspec"
```

```ruby
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

The `:mock_openai` tag wires everything up and resets state between tests automatically.

**Minitest:**

```ruby
# test/test_helper.rb
require "mock_openai/minitest"

# If your code makes real HTTP connections to the LLM API (CLI tools,
# integration tests, background jobs), start the server once here:
MockOpenAI.start_test_server!

RubyLLM.configure do |config|
  config.anthropic_api_base = MockOpenAI.server_url
end
```

```ruby
class MyChatTest < Minitest::Test
  include MockOpenAI::Minitest

  def test_returns_canned_response
    MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
    assert_equal "Hi!", MyService.call_openai("Hello")
  end
end
```

`MockOpenAI::Minitest` hooks into `before_setup` and `after_teardown` to reset state automatically. `start_test_server!` is idempotent and blocks until the server is ready.

---

## Documentation

Full documentation is available at **[grymoire7.github.io/mockopenai](https://grymoire7.github.io/mockopenai)**:

- [Getting Started](https://grymoire7.github.io/mockopenai/getting-started/): installation, setup, first test
- [Usage](https://grymoire7.github.io/mockopenai/usage/): in-process vs. standalone server modes
- [Examples](https://grymoire7.github.io/mockopenai/examples/): multi-step conversations, failure modes, templates
- [Reference](https://grymoire7.github.io/mockopenai/reference/): full API, RSpec tags, CLI, and configuration

---

## Contributing

PRs welcome. Open an issue to discuss new failure modes, matchers, or integrations.

---

## License

MIT
