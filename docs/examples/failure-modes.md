---
title: Failure Modes
parent: Examples
nav_order: 2
---

# Failure Mode Examples

Failures are specified per-rule, not per-test, so you can mix success and
failure in a single test run:

```ruby
it "handles mixed outcomes", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Step 1", response: "OK" },
    { match: "Step 2", failure_mode: :timeout },
    { match: "Step 3", response: "Done" }
  ])

  expect(MyService.step1).to eq("OK")
  expect { MyService.step2 }.to raise_error(Timeout::Error)
  expect(MyService.step3).to eq("Done")
end
```

## Available failure modes

| Symbol | Behavior |
|--------|----------|
| `:timeout` | Sleeps for configured duration (simulates slow/unresponsive LLM) |
| `:rate_limit` | Returns HTTP 429 with rate limit error body |
| `:malformed_json` | Returns syntactically invalid JSON |
| `:internal_error` | Returns HTTP 500 with server error body |
| `:truncated_stream` | Sends partial SSE chunks then closes connection |
