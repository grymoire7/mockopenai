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
