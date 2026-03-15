---
title: In-Process
parent: Usage
nav_order: 1
---

# In-Process Usage

For tests that call your Ruby service objects or controllers directly,
no server process is needed. The mock handler runs inside the test process
via rack-test.

State is shared via a JSON file that both the test and the Rack handler
read/write within the same process. No ports, no sockets.

## RSpec

```ruby
# spec/rails_helper.rb
require "mock_openai/rspec"
```

```ruby
# spec/services/my_service_spec.rb
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

See [RSpec Metadata](rspec-metadata) for the full list of tags.

## Minitest

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

See [Minitest](minitest) for details.
