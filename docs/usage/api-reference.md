---
title: API Reference
parent: Usage
nav_order: 3
---

# API Reference

```ruby
MockOpenAI.set_responses([...])          # Set ordered rules for this test
MockOpenAI.set_failure_mode(:timeout)    # Convenience: apply one failure to all requests
MockOpenAI.reset!                        # Clear all rules (called automatically between tests)

MockOpenAI.start_test_server!            # Start server in background thread (idempotent, blocks until ready)
MockOpenAI.server_url                    # Returns "http://127.0.0.1:<port>" — use to configure your LLM client
```

## Supported endpoints

| Endpoint | API |
|---|---|
| `POST /v1/chat/completions` | OpenAI Chat Completions |
| `POST /v1/messages` | Anthropic Messages |
