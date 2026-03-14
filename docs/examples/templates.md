---
title: Templates
parent: Examples
nav_order: 3
---

# Template Examples

Dynamic responses using template variables:

```ruby
MockOpenAI.set_responses([
  { match: ".*", template: "Mock reply to: {{last_user_message}}" }
])
```

Supported variables: `{{last_user_message}}`, `{{system_message}}`, `{{model}}`
