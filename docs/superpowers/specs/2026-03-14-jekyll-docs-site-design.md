# Jekyll Documentation Site Design

**Date:** 2026-03-14
**Project:** MockOpenAI
**Status:** Approved

## Overview

Add a Jekyll documentation site hosted on GitHub Pages at
`https://grymoire7.github.io/mockopenai`. The site follows the pattern
established in the `jojo` project: Jekyll with the `just-the-docs` theme,
built from a `docs/` subdirectory, deployed via GitHub Actions.

## File Structure

```
docs/
  _config.yml
  Gemfile
  Gemfile.lock
  index.md                        # Home (nav_order: 1)
  getting-started/
    index.md                      # Section landing (nav_order: 2, has_children: true)
    installation.md
    quick-start.md
  usage/
    index.md                      # nav_order: 3
    in-process.md
    standalone.md
    api-reference.md
    rspec-metadata.md
  examples/
    index.md                      # nav_order: 4
    basic.md
    failure-modes.md
    templates.md
  reference/
    index.md                      # nav_order: 5
    cli.md
    configuration.md
    how-it-works.md

.github/
  workflows/
    pages.yml
```

## Jekyll Configuration

### `docs/_config.yml`

```yaml
title: MockOpenAI
description: >-
  A local mock server for OpenAI-compatible APIs — deterministic responses
  and per-request failure simulation for any Ruby application.
baseurl: "/mockopenai"
url: "https://grymoire7.github.io"

theme: just-the-docs
plugins:
  - jekyll-feed

aux_links:
  "MockOpenAI on GitHub":
    - "//github.com/grymoire7/mockopenai"

aux_links_new_tab: true

defaults:
  - scope:
      path: ""
    values:
      layout: default

exclude:
  - plans/
  - architecture.md
  - design.md
  - mvp.md
  - demo.md
  - demo_api.rb
  - demo_http.rb
  - demo_rspec_spec.rb
```

### `docs/Gemfile`

```ruby
source "https://rubygems.org"

gem "jekyll", "~> 4.4.1"
gem "just-the-docs"

group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.12"
end
```

## GitHub Actions Workflow

`.github/workflows/pages.yml` mirrors jojo's workflow exactly:

- Triggers on push to `main` when `docs/**` or the workflow file changes
- Runs `bundle exec jekyll build` from the `docs/` working directory
- Uploads `docs/_site` as the Pages artifact
- Deploys via `actions/deploy-pages@v4`

## Content Mapping

All content sourced from the existing README — reorganized, not rewritten.

| File | Source |
|------|--------|
| `index.md` | README intro + features list |
| `getting-started/installation.md` | README Installation section |
| `getting-started/quick-start.md` | README Usage Patterns intro |
| `usage/in-process.md` | README "In-process" usage pattern |
| `usage/standalone.md` | README "Standalone server" usage pattern |
| `usage/api-reference.md` | README Public API section |
| `usage/rspec-metadata.md` | README RSpec Metadata Reference table |
| `examples/basic.md` | README Examples — simple + multi-step |
| `examples/failure-modes.md` | README Examples — failure modes |
| `examples/templates.md` | README Examples — templates |
| `reference/cli.md` | README CLI Reference section |
| `reference/configuration.md` | README Configuration section |
| `reference/how-it-works.md` | README How It Works section |

Section `index.md` files are thin landing pages (front matter + one-line description).

## Existing Docs

Files in `docs/` that are internal planning/design artifacts are excluded from
the Jekyll build via `_config.yml`'s `exclude` list. They remain in the repo:

- `architecture.md`, `design.md`, `mvp.md`, `demo.md`
- `demo_api.rb`, `demo_http.rb`, `demo_rspec_spec.rb`
- `plans/`

## Out of Scope

- Mermaid diagrams (not needed for this content)
- Custom theme overrides
- Search configuration beyond just-the-docs defaults
- Any content not already in the README
