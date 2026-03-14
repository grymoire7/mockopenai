---
title: How It Works
parent: Reference
nav_order: 3
---

# How It Works

1. Your tests write rules to `tmp/mock_openai_state.json` via `MockOpenAI.set_responses`
2. The mock server reads this file on every request (stateless)
3. It extracts the last user message from the request body
4. It finds the first matching rule (exact → regex → substring)
5. It applies the rule: failure mode, static response, or template
6. If no rule matches, it returns the configured default response

The server stores no internal state. All behavior is driven by the shared
state file, making tests fully deterministic and isolated.
