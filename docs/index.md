---
title: Home
layout: home
nav_order: 1
---

# MockOpenAI

A local mock server for OpenAI-compatible APIs — deterministic responses and
per-request failure simulation for any Ruby application.

MockOpenAI lets you test any Ruby app that calls an LLM **without hitting real
APIs**. It works with Rails, Sinatra, CLI tools, background jobs, or plain Ruby
scripts.

## Features

- **Drop-in replacement** for `/v1/chat/completions`
- **Unified rule engine** for success + failure behavior
- **Per-request matching** (exact, substring, regex)
- **Simulate real LLM failures**, including:
  - Timeouts
  - Rate limits
  - Malformed JSON
  - Internal server errors
  - Truncated streaming
- **RSpec metadata API** (works with Rails, Sinatra, or plain Ruby)
- **Stateless local mock server** for end-to-end and system tests
- **File-based shared state** (no client wrapping, no monkey-patching)
- **Deterministic tests** for CI/CD
- **Zero token costs**
- **Fast, reliable CI**
