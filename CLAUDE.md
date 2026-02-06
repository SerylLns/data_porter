# CLAUDE.md

## Project
DataPorter - Mountable Rails engine for 3-step data import workflows.

## Stack
- Ruby >= 3.2, Rails >= 7.0
- store_model, phlex, turbo-rails, stimulus
- Tailwind CSS (prefixed `dp-`, scoped `.data-porter`)
- RSpec for testing

## Language
- ALL code, comments, commits, docs, specs, error messages in English
- NO French anywhere in the codebase

## Conventions
- NO COMMENTS in generated code
- Conventional Commits (feat, fix, test, refactor, chore, docs)
- Frozen string literals (`# frozen_string_literal: true` in every .rb file)

## Development Constraints

### TDD
- Always write specs BEFORE implementation code
- Red -> Green -> Refactor cycle
- Run `bundle exec rspec` to validate before moving on

### Code Quality
- One file = one class/module
- Max 10 lines per method (excluding private keyword lines)
- Single Responsibility Principle: each class does one thing
- No `class_eval`, no monkey-patching
- No implicit dependencies between modules (explicit requires)
- Everything namespaced under `DataPorter::`
- Run `bundle exec rubocop` before every commit

### Commits
- Small, focused commits (one concern per commit)
- Never commit large chunks of unrelated code together
- Each commit should pass specs and rubocop

### Design Principles
- Balance simplicity and extensibility: simple code that can evolve
- The gem MUST remain business-agnostic (no domain logic, no hardcoded model names)
- All business logic belongs in Targets defined by the host app
- Prefer composition over inheritance
- Expose hooks and configuration, not internal state

## Architecture
See docs/SPEC.md for full specification.

## Commands
- `bundle exec rspec` - run tests
- `bundle exec rubocop` - lint

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
