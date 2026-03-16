---
title: Minitest
parent: Usage
nav_order: 5
---

# Minitest

Add `require "mock_openai/minitest"` to `test/test_helper.rb` once, then
include `MockOpenAI::Minitest` in any test class that needs it.

```ruby
# test/test_helper.rb
require "mock_openai/minitest"
```

```ruby
# test/services/my_service_test.rb
class MyChatTest < Minitest::Test
  include MockOpenAI::Minitest

  def test_returns_canned_response
    MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
    assert_equal "Hi!", MyService.call_openai("Hello")
  end
end
```

`MockOpenAI::Minitest` hooks into Minitest's `before_setup` and
`after_teardown` callbacks, so state is reset before and after each test
without interfering with your own `setup` and `teardown` methods.

## Starting the test server

`MockOpenAI::Minitest` resets state between tests but does not start a server.
If your code makes **outbound HTTP connections** to an LLM API — CLI tools,
Rails apps calling the API in integration tests, background jobs — you must
start a server process and point your LLM client at it.

Call `MockOpenAI.start_test_server!` once at the top of `test/test_helper.rb`
and configure your LLM client to use `MockOpenAI.server_url`:

```ruby
# test/test_helper.rb
require "mock_openai/minitest"

MockOpenAI.start_test_server!

RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", "test-key")
  config.anthropic_api_base = MockOpenAI.server_url
end
```

`start_test_server!` is idempotent — calling it more than once is safe. It
blocks until the server is accepting connections.

`start_test_server!` is **not** needed when testing a Rack app directly via
`rack-test` (e.g. in MockOpenAI's own spec suite, where requests go through
the Rack stack in-process without opening a TCP connection).

## Failure modes

There are no shortcut tags in Minitest (unlike RSpec metadata). Set failure
modes explicitly in your test or `setup`:

```ruby
def test_falls_back_on_rate_limit
  MockOpenAI.set_failure_mode(:rate_limit)

  result = SmartService.call("summarize this")

  assert_equal :cache, result[:source]
end
```

Available failure modes: `:timeout`, `:rate_limit`, `:internal_error`,
`:malformed_json`, `:truncated_stream`.
