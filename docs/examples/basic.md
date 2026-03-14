---
title: Basic Examples
parent: Examples
nav_order: 1
---

# Basic Examples

## Simple canned response

```ruby
it "returns a canned response", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Hello", response: "Hi!" }
  ])

  expect(MyService.call_openai("Hello")).to eq("Hi!")
end
```

## Multi-step conversation

Rules are matched in order (first match wins) using exact, substring, or
regex matching against the last user message.

```ruby
it "handles a multi-step conversation", :mock_openai do
  MockOpenAI.set_responses([
    { match: "Hello", response: "Hi!" },
    { match: "^Order.*", response: "Order shipped." },
    { match: "Thanks", response: "You're welcome!" }
  ])

  result = MyService.complex_flow

  expect(result[:greeting]).to eq("Hi!")
  expect(result[:order]).to eq("Order shipped.")
  expect(result[:closing]).to eq("You're welcome!")
end
```
