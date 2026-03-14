# MockOpenAI Gem Demo

*2026-03-14T14:54:30Z by Showboat 0.6.0*
<!-- showboat-id: 54dc9029-a9fa-4429-a3d3-719a9c6db460 -->

MockOpenAI is a local Rack-based mock server gem for OpenAI-compatible APIs. It lets your test suite control server behaviour via a shared state file — no monkey-patching, no network, no separate process needed for integration tests.

## 1. CLI

The `mock-openai` binary ships with three commands.

```bash
bundle exec ruby bin/mock-openai check
```

```output
MockOpenAI configuration:
  port:             4000
  timeout_seconds:  5
  default_response: Mock response from MockOpenAI
  state_file:       tmp/mock_openai_state.json
```

## 2. Public Ruby API

Tests interact with the mock via three simple class methods.

```bash
bundle exec ruby docs/demo_api.rb
```

```output
Rules written: 3
  hello        => Hi there!
  ^Order       => Your order is on its way.
  .*           => I don't understand that.

Current failure mode: rate_limit
After reset — rules: 0, mode: nil
```

## 3. HTTP Handler

The handler speaks the OpenAI chat completions wire format. Here we drive it directly with rack-test — no server process needed.

```bash
bundle exec ruby docs/demo_http.rb
```

```output
/Users/tracy/.rbenv/versions/3.4.5/lib/ruby/gems/3.4.0/gems/json-2.19.1/lib/json/common.rb:355:in 'JSON::Ext::Parser.parse': unexpected end of input at line 1 column 16 (JSON::ParserError)
	from /Users/tracy/.rbenv/versions/3.4.5/lib/ruby/gems/3.4.0/gems/json-2.19.1/lib/json/common.rb:355:in 'JSON.parse'
	from docs/demo_http.rb:16:in 'Object#post_chat'
	from docs/demo_http.rb:20:in '<main>'
=== Default response (no rules) ===
[MockOpenAI] POST /v1/chat/completions | rule=0 | mode=malformed_json
```

## 4. RSpec Metadata Integration

Add `require "mock_openai/rspec"` to your `spec_helper.rb` once. After that, metadata tags control mock state automatically — no manual `before`/`after` hooks needed.

```bash
bundle exec rspec docs/demo_rspec_spec.rb --format documentation --no-color
```

```output

MockOpenAI RSpec integration demo
  simulates rate limiting
  simulates server errors
  deterministic responses
    matches exact patterns
    falls back to catch-all
  state isolation between examples
    starts with no rules (state was reset by :mock_openai before hook)

Finished in 0.00548 seconds (files took 0.05957 seconds to load)
5 examples, 0 failures

```

## 5. Full Test Suite

The gem ships with 71 examples covering every class.

```bash
bundle exec rspec --format progress --no-color
```

```output
.......................................................................

Finished in 0.03334 seconds (files took 0.06609 seconds to load)
71 examples, 0 failures

```
