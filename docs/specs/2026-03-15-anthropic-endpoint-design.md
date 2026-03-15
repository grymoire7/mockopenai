# Anthropic Endpoint Support

**Date:** 2026-03-15
**Status:** Approved

## Overview

Add support for the Anthropic Messages API endpoint (`POST /v1/messages`) so
MockOpenAI can serve as a drop-in mock for both OpenAI-compatible and Anthropic
clients. This enables jojo (and similar projects using RubyLLM's Anthropic
provider) to use MockOpenAI without switching providers or monkey-patching.

## Motivation

RubyLLM's Anthropic provider posts to `/v1/messages` and parses
Anthropic-format responses (`content: [{type: "text", text: "..."}]`).
MockOpenAI currently only handles `/v1/chat/completions` (OpenAI format).
Adding the Anthropic endpoint makes MockOpenAI useful for any Ruby project
using Anthropic's API directly or via an abstraction like RubyLLM.

## Architecture

Five files change or are created:

```
lib/mock_openai/handlers/
  base.rb              ← new: shared call(env) flow (template method pattern)
  chat_completions.rb  ← refactored: extends Base, ~10 lines remain
  messages.rb          ← new: Anthropic handler, ~15 lines
lib/mock_openai/
  anthropic_response_builder.rb  ← new: builds Anthropic-format responses
  router.rb            ← updated: add POST /v1/messages route
```

## Components

### Handlers::Base

Abstract base class implementing the full shared `call(env)` flow:

1. Parse JSON body → return 400 on invalid JSON
2. Call `parse_request(body)` (template method) → `{last_user_message:, system_message:, model:}` — **`last_user_message` must be a normalized plain string**
3. Read state, match rules against `last_user_message`
4. If matched rule has `failure_mode` → call `apply_failure_mode(mode, request_context)` (template method)
5. Else resolve content (rule response → rule template → `state["response_template"]` → `state["default_response"]` → config `default_response`), call `build_success_response(content, model)` (template method)
6. Log request

**Template methods (subclasses must implement):**
- `parse_request(body)` → `{last_user_message: String, system_message: String, model: String}`
- `build_success_response(content, model)` → Rack response tuple
- `apply_failure_mode(mode, request_context)` → Rack response tuple — handles provider-specific failure payloads (e.g. `:timeout` body shape, SSE format for `:stream_truncated`)

`request_context` passed to `apply_failure_mode` is the hash returned by `parse_request`: `{last_user_message:, system_message:, model:}`. Handlers may use `model` to echo the model name in failure responses (e.g. SSE chunks), but are not required to.

**Shared helper** `extract_text_content(content)` normalizes plain strings and content-block arrays. `parse_request` implementations must call this when extracting `last_user_message`:

```ruby
def extract_text_content(content)
  if content.is_a?(Array)
    content.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
  else
    content.to_s
  end
end
```

This handles vision/multimodal requests for both providers.

### Handlers::ChatCompletions

Refactored to extend `Base`. Implements three template methods:

- `parse_request(body)` — extracts last user message from `messages` array (calls `extract_text_content` to normalize); system message from the array entry with `role: "system"`; default model `"mock-gpt-4"`
- `build_success_response(content, model)` — delegates to `ResponseBuilder.build`
- `apply_failure_mode(mode, request_context)` — existing behavior: `:timeout` sleeps then returns OpenAI-format empty choices; `:stream_truncated` sends partial OpenAI SSE chunks

### Handlers::Messages

New handler extending `Base`. Implements three template methods:

- `parse_request(body)` — extracts last user message from `messages` array (calls `extract_text_content` to normalize); system message from top-level `body["system"]` string (Anthropic-specific); default model `"mock-claude-3"`
- `build_success_response(content, model)` — delegates to `AnthropicResponseBuilder.build`
- `apply_failure_mode(mode, request_context)` — `:timeout` sleeps then returns Anthropic-format error body; `:stream_truncated` sends partial Anthropic SSE chunks; other modes (`:rate_limit`, `:malformed_json`, `:internal_error`) return provider-neutral HTTP error responses and work unchanged

### AnthropicResponseBuilder

New class mirroring `ResponseBuilder` but returning Anthropic's message format:

```ruby
{
  "id"           => "mock-msg-#{SecureRandom.hex(8)}",
  "type"         => "message",
  "role"         => "assistant",
  "content"      => [{"type" => "text", "text" => content}],
  "model"        => model,
  "stop_reason"  => "end_turn",
  "stop_sequence" => nil,
  "usage"        => {"input_tokens" => 0, "output_tokens" => 0}
}
```

Id prefix `mock-msg-` distinguishes Anthropic responses in logs from OpenAI's `mock-chatcmpl-`.

### Router

Add route:

```ruby
in ["POST", "/v1/messages"]
  Handlers::Messages.new.call(env)
```

## Request Format Differences

| Field          | OpenAI (`/v1/chat/completions`)       | Anthropic (`/v1/messages`)         |
|----------------|---------------------------------------|------------------------------------|
| System message | `messages` array, `role: "system"`    | Top-level `body["system"]` string  |
| User messages  | `messages` array, `role: "user"`      | `messages` array, `role: "user"`   |
| Content type   | String or content-block array         | String or content-block array      |
| Model          | `body["model"]`                       | `body["model"]`                    |

## Rule Matching

Unchanged. Rules match on `last_user_message` using the existing exact → regex → substring algorithm. The same rules work for both endpoints.

## Error Handling

- Invalid JSON body → 400 with error message (same as existing behavior)
- No matching rule → falls back to `state["response_template"]` → `state["default_response"]` → config `default_response`
- `:rate_limit` and `:internal_error` failure modes return HTTP 429/500 JSON error bodies — these are provider-neutral and work identically across both handlers
- `:malformed_json` returns an intentionally unparseable body fragment. The current fragment (`{ "choices": [`) is OpenAI-specific but the intent is purely to trigger a `JSON::ParserError` — the key name is irrelevant since the body is never successfully parsed. Both handlers use the same fragment; no provider-specific variant is needed.
- `:timeout` and `:stream_truncated` are provider-specific: each handler's `apply_failure_mode` produces the correct format for its provider

## Testing

Four spec files affected:

- **`spec/mock_openai/handlers/base_spec.rb`** (new) — tests shared flow via a minimal concrete double subclass with stub implementations of all three template methods returning neutral test values; covers JSON error handling, rule matching, failure mode dispatch (verifying `apply_failure_mode` is called with the correct mode), and the five-step content resolution chain explicitly: rule response, rule template, `state["response_template"]`, `state["default_response"]`, config default
- **`spec/mock_openai/handlers/messages_spec.rb`** (new) — mirrors `chat_completions_spec.rb`; covers rule matching, failure modes, default response, malformed body, Anthropic system message extraction
- **`spec/mock_openai/anthropic_response_builder_spec.rb`** (new) — mirrors `response_builder_spec.rb`; verifies correct fields, unique ids, content block structure
- **`spec/mock_openai/handlers/chat_completions_spec.rb`** (updated) — remove logic moved to Base; keep OpenAI-specific behavior tests
- **`spec/mock_openai/router_spec.rb`** (updated) — add `/v1/messages` route test
