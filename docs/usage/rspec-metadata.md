---
title: RSpec Metadata
parent: Usage
nav_order: 4
---

# RSpec Metadata

Add `require "mock_openai/rspec"` to `spec/rails_helper.rb` once. Metadata tags then control mock state
automatically — no manual `before`/`after` hooks needed.

| Tag | Behavior |
|-----|----------|
| `:mock_openai` | Enables MockOpenAI; resets state before/after the example |
| `:mock_openai_timeout` | Shortcut: all requests return timeout |
| `:mock_openai_rate_limit` | Shortcut: all requests return 429 |
| `:mock_openai_malformed_json` | Shortcut: all requests return malformed JSON |
| `:mock_openai_internal_error` | Shortcut: all requests return 500 |
| `:mock_openai_truncated_stream` | Shortcut: all requests return truncated stream |

The shortcut tags are equivalent to `set_responses([{ match: ".*", failure_mode: :... }])`.

State is automatically reset after each tagged test — no manual cleanup needed.
