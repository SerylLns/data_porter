---
series: "Building DataPorter - A Data Import Engine for Rails"
author: ""
repo: ""
status: in-progress
---

# Series Plan

## Target audience
Ruby/Rails developers (intermediate+) interested in gem architecture, Rails engines, and clean DSL design.

## Series structure
Each article: ~5-8 min read, one clear concept, real code, decisions explained.

---

## Articles

### Part 1 — Why build a data import engine?
- **Tasks:** None (intro)
- **Hook:** The repetitive import pattern in Rails apps
- **Covers:** Problem statement, existing solutions (maintenance_tasks, activeadmin_import), why a new gem, what we'll build (3-step workflow diagram)
- **Key decisions:** Mountable engine vs. lib, isolate_namespace, target audience
- **File:** `docs/blog/001-why-build-a-data-import-engine.md`
- **Status:** draft

### Part 2 — Scaffolding a Rails Engine gem
- **Tasks:** #1
- **Hook:** `bundle gem` is just the start
- **Covers:** Gem structure, Engine setup, isolate_namespace, directory tree, gemspec dependencies
- **Key decisions:** Why isolate_namespace, directory conventions, dependency choices (store_model, phlex, turbo)
- **Status:** pending

### Part 3 — Configuration DSL: making the gem flexible
- **Tasks:** #2
- **Hook:** A good gem adapts to any host app
- **Covers:** Configuration singleton pattern, DSL with `configure` block, sensible defaults, context_builder lambda
- **Key decisions:** Why not Rails config, lambda vs block for context, what to make configurable vs. convention
- **Status:** pending

### Part 4 — Modeling import data with StoreModel & JSONB
- **Tasks:** #3, #4
- **Hook:** Storing structured data without extra tables
- **Covers:** StoreModel gem, ImportRecord/Error/Report models, JSONB attributes, TypeValidator
- **Key decisions:** JSONB vs. separate tables, store_model vs. hand-rolled, validation strategy (column-level vs DB-level)
- **Status:** pending

### Part 5 — Designing a Target DSL
- **Tasks:** #5, #6
- **Hook:** One file = one import type, zero boilerplate
- **Covers:** Target base class, class-level DSL (label, model, columns, csv_mapping), Registry pattern, auto-discovery
- **Key decisions:** DSL design (class methods vs. instance), class_attribute vs. class instance vars, hook pattern for extensibility
- **Status:** pending

### Part 6 — Parsing CSV data with Sources
- **Tasks:** #7, #8
- **Hook:** The first end-to-end flow
- **Covers:** DataImport model, migration, Source base class, CSV source, ActiveStorage integration, column mapping
- **Key decisions:** Polymorphic user association, enum state machine, auto-mapping vs explicit mapping
- **Status:** pending

### Part 7 — The Orchestrator: coordinating the import workflow
- **Tasks:** #9, #10
- **Hook:** The brain of the engine
- **Covers:** Orchestrator class (parse! and import!), state transitions, error handling per-record, ActiveJob integration
- **Key decisions:** Why an orchestrator (not controller logic), transaction boundaries, error recovery strategy
- **Status:** pending

### Part 8 — Real-time progress with ActionCable & Stimulus
- **Tasks:** #11, #14
- **Hook:** Users hate staring at a spinner with no feedback
- **Covers:** Broadcaster service, ImportChannel, Stimulus controller, progress bar updates, auto-reload on completion
- **Key decisions:** ActionCable vs. polling vs. SSE, channel naming strategy, Stimulus vs. Turbo Streams
- **Status:** pending

### Part 9 — Building the UI with Phlex & Tailwind
- **Tasks:** #13
- **Hook:** Auto-generated preview tables from a DSL
- **Covers:** Phlex components, scoped Tailwind (dp- prefix), preview table with dynamic columns, status badges, CSS custom properties for theming
- **Key decisions:** Phlex vs. ERB/ViewComponent, Tailwind prefix strategy, how to not pollute host app styles
- **Status:** pending

### Part 10 — Controllers & routing in a Rails Engine
- **Tasks:** #12
- **Hook:** Engine controllers are tricky — here's the clean way
- **Covers:** ImportsController, inheriting from host's parent controller, engine routes, strong params, Turbo integration
- **Key decisions:** Dynamic parent controller inheritance, route namespacing, how auth flows from host to engine
- **Status:** pending

### Part 11 — Generators: install & target scaffolding
- **Tasks:** #15, #16
- **Hook:** Great gems install in one command
- **Covers:** Install generator (migration, initializer, routes), Target generator (column parsing, template), Rails::Generators API
- **Key decisions:** What to generate vs. what to configure, template format (ERB .tt), route injection strategy
- **Status:** pending

### Part 12 — Adding JSON & API sources
- **Tasks:** #18, #19
- **Hook:** CSV is just the beginning
- **Covers:** JSON source (file + raw text), API source (HTTP client, params injection), source plugin architecture
- **Key decisions:** Source abstraction design, how to handle auth headers, response_root extraction
- **Status:** pending

### Part 13 — Testing a Rails Engine with RSpec
- **Tasks:** #17
- **Hook:** Testing an engine is different from testing an app
- **Covers:** Dummy app setup, spec organization, testing StoreModels, mocking ActiveStorage, testing jobs, controller specs
- **Key decisions:** Dummy app vs. shared examples, factory vs. fixture, what to unit test vs. integration test
- **Status:** pending

### Part 14 — Dry Run: validate before you persist
- **Tasks:** #20
- **Hook:** Preview catches column errors, dry-run catches DB errors
- **Covers:** Transaction + rollback pattern, enriching records with DB errors, DryRunJob, UI integration
- **Key decisions:** Why two validation layers, transaction rollback approach, when to offer dry-run
- **Status:** pending

### Part 15 — Publishing the gem & retrospective
- **Tasks:** None (wrap-up)
- **Hook:** From idea to rubygems.org
- **Covers:** Gemspec final polish, CHANGELOG, versioning, publishing, series recap, what worked, what we'd do differently
- **Key decisions:** Semantic versioning strategy, open source considerations
- **Status:** pending
