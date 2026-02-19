---
title: Contributing
icon: material/heart
---

# Contributing to DataPorter

## Bug Reports

Open an issue on [GitHub](https://github.com/SerylLns/data_porter/issues) with:

- Ruby and Rails versions
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or error messages

## Pull Requests

1. Fork the repo and create your branch from `main`
2. Write specs first (TDD -- red, green, refactor)
3. Ensure `bundle exec rspec` passes (0 failures)
4. Ensure `bundle exec rubocop` passes (0 offenses)
5. One concern per commit, using [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `test:`, `refactor:`, `chore:`, `docs:`)
6. Open a PR against `main`

## Development Setup

```bash
git clone https://github.com/SerylLns/data_porter.git
cd data_porter
bin/setup
bundle exec rspec
bundle exec rubocop
```

## Code Style

- `# frozen_string_literal: true` in every `.rb` file
- Max 10 lines per method
- No comments in code -- code should be self-explanatory
- Everything namespaced under `DataPorter::`
- All English (code, commits, docs, specs, error messages)
- `dp-` CSS prefix, scoped under `.data-porter`

## Architecture

- The gem must remain **business-agnostic** -- no domain logic, no hardcoded model names
- All business logic belongs in Targets defined by the host app
- Prefer composition over inheritance
- Expose hooks and configuration, not internal state
