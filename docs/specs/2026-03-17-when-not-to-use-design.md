# Design: "When not to use MockOpenAI" page

Date: 2026-03-17

## Goal

Add a top-level documentation page that honestly addresses when MockOpenAI is
not the right tool. The intent is to build trust and demonstrate expertise by
helping readers make the right decision, even if that means not using this gem.

## New file

`docs/when-not-to-use.md`

Jekyll frontmatter:
```yaml
---
title: When not to use MockOpenAI
nav_order: 6
---
```

`nav_order: 6` is confirmed non-conflicting. Existing top-level pages use 1
(Home), 2 (Getting Started), 3 (Usage), 4 (Examples), 5 (Reference).

## Page structure

### 1. Intro (2-3 sentences)

Honest framing: MockOpenAI is worth the overhead in specific circumstances, and
a simpler approach often wins. The goal is to help readers choose the right
tool, not to advocate for this one.

### 2. When a helper method is enough

Prose covering three scenarios where a simple in-project helper is sufficient:

- **Single high-level library**: The app uses one library (e.g., RubyLLM) that
  wraps all LLM calls. Tests only need happy-path responses and basic exception
  raising. No HTTP layer is involved.

- **Pure unit tests only**: Tests verify logic within a single class. The LLM
  call is one of several dependencies being stubbed. HTTP-layer fidelity
  provides no value.

- **Minimal test dependencies preferred**: Coupling to the library's internal
  API is acceptable, and adding a local server to the test suite is more
  complexity than the project needs.

Include the following helper method code inline as a concrete example of what
"simple enough" looks like:

```ruby
module RubyLLMMocks
  def mock_ruby_llm_chat(content: nil, error: nil)
    if error
      allow(RubyLLM).to receive(:chat).and_raise(error)
    else
      mock_response = instance_double(
        RubyLLM::Message,
        content: content,
        inspect: "RubyLLM::Message(content: #{content.inspect})"
      )

      mock_chat_with_schema = instance_double(
        RubyLLM::Chat,
        ask: mock_response
      )

      mock_chat = instance_double(
        RubyLLM::Chat,
        with_schema: mock_chat_with_schema
      )

      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    end
  end
end
```

After the code block, add a note that this is a real-world example from the
[hyrum project](https://github.com/grymoire7/hyrum/blob/main/spec/support/ruby_llm_mocks.rb)
as a hyperlink. One sentence, no further attribution needed.

Note the tradeoff: this helper is tightly coupled to RubyLLM's internal API
(`.with_schema`, `.ask`, `RubyLLM::Chat`). It breaks when the library
refactors, but the failure is immediate and easy to fix.

Also note: this approach handles error simulation just fine for wrapper
library users. Passing `error: RubyLLM::RateLimitError.new(...)` raises the
same exception your application code would see in production. MockOpenAI's failure modes add value when you need the full HTTP stack
exercised: actual TCP delays, mid-stream cutoffs, or response header parsing.
They are not needed for simulating the typed exceptions a library like RubyLLM
already surfaces.

### 3. When MockOpenAI earns its place

3-4 bullets as a mirror section, so the page is not purely negative:

- Raw HTTP client or multiple LLM clients in use
- Integration or system tests that make real HTTP connections
- Need to test actual HTTP behavior: TCP-level timeouts, truncated streams,
  or retry-after header parsing (not just exception handling that a wrapper
  library like RubyLLM already surfaces)
- Background jobs or Capybara system tests where object-level mocking is awkward

End with: "For full details, see [Getting started](getting-started/)." The
relative link is intentional and resolves correctly within the Jekyll site.
(The README uses absolute URLs, but internal docs pages use relative links.)

### 4. Mermaid decision diagram

A flowchart with three sequential binary decision nodes. The "yes" path at any
node routes immediately to "Use MockOpenAI" (terminal). The "no" path cascades
down to the next node. After all three "no" answers, the terminal is "A helper
method is probably enough."

Exact cascade:

```
Start
  |
  v
[1] Do you use the raw OpenAI or Anthropic HTTP client
    (not wrapped by a library like RubyLLM)?
  |yes --> [Use MockOpenAI]
  |no
  v
[2] Do you need to test actual HTTP behavior (TCP-level timeouts,
    truncated streams, retry-after header parsing) rather than
    just handling the exceptions your wrapper library raises?
  |yes --> [Use MockOpenAI]
  |no
  v
[3] Do you run integration or system tests
    that make real HTTP calls?
  |yes --> [Use MockOpenAI]
  |no
  v
[A helper method is probably enough]
```

Fallback: if Mermaid proves difficult to wire into the Jekyll theme (more than
3 attempts), replace with a simple markdown comparison table instead:
- Rows = the three decision factors: (1) raw HTTP client, (2) actual HTTP
  behavior like TCP timeouts/truncated streams/retry headers, (3) integration
  or system tests
- Columns = "Helper method" vs. "MockOpenAI"
- Cell content = brief phrase indicating which is better suited

## Links to update

### README.md

Add a single sentence as a new paragraph between the last bullet of the "Why
MockOpenAI?" section and the following `---` divider. Include a blank line
above and below the new sentence. Text:

> Not sure if MockOpenAI is right for your project? See
> [When not to use MockOpenAI](https://grymoire7.github.io/mockopenai/when-not-to-use/).

Use the full GitHub Pages URL, consistent with the existing README link pattern
(see the Documentation section of the README for examples).

### docs/landing/index.html

The landing page is a standalone HTML file excluded from Jekyll (see
`_config.yml`). It is served from a different URL than the docs site, so all
links to docs pages must use absolute URLs.

Add a sentence at the end of the "THE PROBLEM" section. Place the new paragraph after the closing `</div>` of the comparison grid
(line ~387), inside the `max-w-6xl` container div, before that container's
closing `</div>` at line ~389.

Surrounding context for the insertion point:

```html
      </div>               ← closing </div> of comparison grid
                           ← INSERT NEW <p> HERE
    </div>                 ← closing </div> of max-w-6xl container
  </section>
```

Suggested markup (match existing section text styles, `reveal` class for
scroll-triggered fade-in):

```html
<p class="reveal text-center text-slate-500 text-xs mt-10">
  Not sure if MockOpenAI is right for your project?
  <a href="https://grymoire7.github.io/mockopenai/when-not-to-use/" class="text-electric-400 hover:text-electric-300 transition-colors">When not to use MockOpenAI</a>.
</p>
```

## Writing guidelines

- Sentence case for all headings and subheadings
- No em-dashes
- Simple, direct language
- No AI writing cliches ("not just X, but Y", "the real X is...")
- Consistent tone with existing docs pages
