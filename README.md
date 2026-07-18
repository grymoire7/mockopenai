<p align="center">
  <img src="docs/assets/img/mockopenai_logo_medium.png" alt="MockOpenAI logo" />
</p>

# MockOpenAI

A local mock server for OpenAI-compatible and Anthropic APIs, with deterministic responses and per-request failure simulation.

[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://grymoire7.github.io/mockopenai)
![Tests](https://github.com/grymoire7/mockopenai/actions/workflows/ruby.yml/badge.svg?branch=main)
![Ruby Version](https://img.shields.io/badge/Ruby-%3E%3D%203.0-green?logo=Ruby&logoColor=red&label=Ruby%20version&color=green)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/grymoire7/mockopenai/blob/main/LICENSE)

## Overview

MockOpenAI lets you test any Ruby app that calls an LLM without hitting real APIs, spending real money, or waiting on rate limits. It supports the OpenAI Chat Completions API (`POST /v1/chat/completions`) and the Anthropic Messages API (`POST /v1/messages`). It works with Rails, Sinatra, CLI tools, background jobs, or plain Ruby scripts.

- **No API keys needed**: zero token costs, zero network calls in CI
- **Deterministic**: control exactly what the LLM "says" for each request
- **Per-request failure modes**: simulate timeouts, rate limits, malformed JSON, and more
- **No app changes**: no monkey-patching, no client wrapping, no test doubles
- **Fast CI**: tests run at local speed, not API speed
- **OpenAI + Anthropic**: supports `POST /v1/chat/completions` and `POST /v1/messages`

Not sure if MockOpenAI is right for your project? See [When not to use MockOpenAI](https://grymoire7.github.io/mockopenai/when-not-to-use/).

PRs are welcome. Open an issue to discuss new failure modes, matchers, or integrations.

## Stack

- Ruby, version 3.0 or newer (this repo develops against 3.4.5 via mise)
- Rack and Rackup, serving the mock HTTP server on WEBrick
- RSpec and Minitest integrations for the test helper
- StandardRB for style checks

## Setup

Add the gem to your test group and install it:

```ruby
# Gemfile
group :test do
  gem "mock_openai"
end
```

```bash
bundle install
```

Then wire it into your test suite.

**RSpec:**

```ruby
# spec/rails_helper.rb
require "mock_openai/rspec"

# If your code makes real HTTP connections to the LLM API (CLI tools,
# integration tests, background jobs), start the server once here:
MockOpenAI.start_test_server!

RubyLLM.configure do |config|
  config.anthropic_api_base = MockOpenAI.server_url
end
```

```ruby
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

The `:mock_openai` tag wires everything up and resets state between tests automatically. `start_test_server!` is idempotent and blocks until the server is ready.

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

## Tasks

Day-to-day commands, run from the repo root.

- `pitchfork start` starts the mock server (`bin/mock-openai start --port=4000`) as a persistent background daemon on port 4000. This is different from `MockOpenAI.start_test_server!` shown in Setup above, which spins up a standalone server scoped to a single test run.
- `mise run test` runs the RSpec suite.
- `mise run lint` runs the StandardRB style check.

## Documentation

Full documentation is at [grymoire7.github.io/mockopenai](https://grymoire7.github.io/mockopenai):

- [Getting Started](https://grymoire7.github.io/mockopenai/getting-started/): installation, setup, first test
- [Usage](https://grymoire7.github.io/mockopenai/usage/): in-process vs. standalone server modes
- [Examples](https://grymoire7.github.io/mockopenai/examples/): multi-step conversations, failure modes, templates
- [Reference](https://grymoire7.github.io/mockopenai/reference/): full API, RSpec tags, CLI, and configuration

## License

MIT
