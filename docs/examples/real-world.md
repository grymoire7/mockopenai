---
title: Real-World Scenarios
parent: Examples
nav_order: 4
---

# Real-World Scenarios

The simplest cases really are this simple:

```ruby
it "greets the user", :mock_openai do
  MockOpenAI.set_responses([{ match: "Hello", response: "Hi!" }])
  expect(MyService.greet).to eq("Hi!")
end
```

That simplicity isn't a limitation; it's the baseline. The same one-liner approach
scales to multi-stage pipelines, failure injection, and exhaustive resilience
testing. The examples below show how.

---

## Multi-stage AI pipeline

Many real applications make several AI calls in sequence: classify first, then
extract, then format. Each call has a different prompt, so you can match each
stage independently and verify the whole pipeline in a single test.

```ruby
# DocumentProcessor calls the AI three times:
#   1. "Classify this document: ..."     → classification JSON
#   2. "Extract fields from invoice: ..." → structured data JSON
#   3. "Summarize in one sentence: ..."  → plain-text summary

describe DocumentProcessor do
  it "processes an invoice through the full pipeline", :mock_openai do
    MockOpenAI.set_responses([
      {
        match: "Classify this document",
        response: '{"type":"invoice","confidence":0.97}'
      },
      {
        match: "^Extract fields from invoice",
        response: '{"vendor":"Acme Corp","amount":"$1,200","due":"2024-02-01"}'
      },
      {
        match: "^Summarize",
        response: "Invoice from Acme Corp for $1,200, due February 1, 2024."
      }
    ])

    result = DocumentProcessor.new(invoice_fixture).process

    expect(result.type).to eq("invoice")
    expect(result.extracted["vendor"]).to eq("Acme Corp")
    expect(result.summary).to include("Acme Corp")
  end
end
```

Rules match against the **last user message**, top-to-bottom, first match
wins. Because each pipeline stage sends a different prompt, three rules are
enough to cover all three stages. No stubs, no monkey-patching, no changes to
`DocumentProcessor` itself.

---

## Failure injection at a specific pipeline stage

The same pipeline, but now you want to test what happens when the extraction
step fails. Because failure modes are per-rule, you can let stage one succeed
and make stage two blow up, all in one test, no test doubles required.

```ruby
describe DocumentProcessor do
  it "queues for manual review when extraction fails", :mock_openai do
    MockOpenAI.set_responses([
      {
        match: "Classify this document",
        response: '{"type":"invoice","confidence":0.97}'
      },
      {
        match: "^Extract fields",
        failure_mode: :internal_error        # stage 2 returns HTTP 500
      }
      # stage 3 is never reached
    ])

    result = DocumentProcessor.new(invoice_fixture).process

    expect(result.status).to eq(:pending_manual_review)
    expect(result.failed_stage).to eq(:extraction)
  end

  it "retries extraction on a transient timeout", :mock_openai do
    MockOpenAI.set_responses([
      {
        match: "Classify this document",
        response: '{"type":"invoice","confidence":0.97}'
      },
      {
        match: "^Extract fields",
        failure_mode: :timeout               # first extraction attempt times out
      },
      {
        match: "^Extract fields",
        response: '{"vendor":"Acme Corp","amount":"$1,200","due":"2024-02-01"}'
      },
      {
        match: "^Summarize",
        response: "Invoice from Acme Corp for $1,200, due February 1, 2024."
      }
    ])

    result = DocumentProcessor.new(invoice_fixture).process

    expect(result.status).to eq(:complete)
    expect(result.extracted["vendor"]).to eq("Acme Corp")
  end
end
```

The retry test works because rules are consumed in order. The first `Extract
fields` rule fires on the initial attempt (timeout), and the second one fires
on the retry (success). The pipeline never knows it is talking to a mock.

---

## Exhaustive resilience testing

This is where MockOpenAI pays back the most. A content-generation service needs
to handle every category of API failure gracefully: rate limits, timeouts,
malformed responses, and hard server errors. With RSpec metadata tags, you can
cover all four in as many lines.

```ruby
describe ArticleAssistant do
  subject(:result) { ArticleAssistant.summarize(long_article) }

  context "when the API is rate limited", :mock_openai_rate_limit do
    it "raises a retryable error" do
      expect { result }.to raise_error(ArticleAssistant::RateLimitError)
    end
  end

  context "when the API times out", :mock_openai_timeout do
    it "raises a retryable error" do
      expect { result }.to raise_error(ArticleAssistant::TimeoutError)
    end
  end

  context "when the API returns malformed JSON", :mock_openai_malformed_json do
    it "returns the fallback summary instead of crashing" do
      expect(result).to eq(ArticleAssistant::FALLBACK_SUMMARY)
    end
  end

  context "when the API returns a 500", :mock_openai_internal_error do
    it "raises a non-retryable error" do
      expect { result }.to raise_error(ArticleAssistant::ServiceError)
    end
  end
end
```

Each tag automatically resets state before the example and restores it
afterward, so the tests are fully isolated from each other. This pattern lets
you prove your error handling actually works, not just that you have a `rescue`
clause, without ever hitting a real API or waiting for a real timeout.

### Why this matters

Testing AI-failure handling against a live API is impractical:
- Rate limits are unpredictable and cost money.
- Timeouts take seconds to trigger and are hard to reproduce.
- Malformed responses and 500s almost never happen in development.

MockOpenAI makes every failure mode instant, free, and deterministic. A test
suite that would otherwise skip resilience tests entirely can now cover them all
in milliseconds.
