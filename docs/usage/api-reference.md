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
```
