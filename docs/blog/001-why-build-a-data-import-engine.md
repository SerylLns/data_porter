---
title: "Building DataPorter #1 — Why build a data import engine?"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 1
tags: [ruby, rails, rails-engine, gem-development, architecture, open-source]
published: false
---

# Why build a data import engine?

> Every Rails app eventually needs to import data. Let's stop rewriting the same workflow every time.

## Context

This is the first article in a series where we build **DataPorter**, a mountable Rails engine for data import workflows, from scratch. We'll go from `bundle gem` to a published rubygem, covering architecture decisions, DSL design, testing strategies, and everything in between.

By the end of this series, you'll have a deep understanding of how to build a production-ready Rails engine — and a reusable gem to show for it.

## The problem

If you've worked on any non-trivial Rails application, you've probably written this code more than once:

1. Upload a CSV (or fetch data from an API)
2. Parse and validate each row
3. Show the user what's about to be imported
4. Persist the valid records to the database

Maybe it was a guest list for a hotel app. Maybe vendor data for an e-commerce platform. Maybe scraped listings from an external API.

The specifics change, but the workflow is always the same. And every time, we rebuild it from scratch: a controller action here, some CSV parsing there, a background job, maybe a progress bar if we're feeling fancy.

The result? Scattered import logic across controllers, services, and jobs. No consistency. No reuse. Every new import type means rewriting the same infrastructure.

## What we're building

DataPorter is a mountable Rails engine that provides the entire import infrastructure. The host app only defines the business part: *what* to import and *how* to persist it.

One file, one class, one import type:

```ruby
# app/importers/guests_target.rb
class GuestsTarget < DataPorter::Target
  label "Guests"
  model Guest
  sources :csv, :json

  columns do
    column :first_name, type: :string, required: true
    column :last_name,  type: :string, required: true
    column :email,      type: :email
    column :phone,      type: :phone
  end

  def persist(record, context:)
    Guest.create!(hotel: context.hotel, **record.attributes)
  end
end
```

That's it. DataPorter handles the rest: file upload, parsing, validation, preview UI, progress tracking, error reporting, and background processing.

The workflow is always three steps:

```
Upload / Configure  →  Preview & Validate  →  Import
```

## Why not use what already exists?

There are existing solutions in the Rails ecosystem. Let's look at the two most common approaches.

### The DIY approach

Most teams build custom import flows per model. It works, but it doesn't scale. By the third import type, you're copy-pasting controller actions and wishing you had abstracted earlier.

### maintenance_tasks

Shopify's [maintenance_tasks](https://github.com/Shopify/maintenance_tasks) gem is excellent for one-off data processing scripts. It provides a UI, background processing, and CSV support.

But it solves a different problem. It's designed for fire-and-forget maintenance operations, not interactive import workflows.

| Aspect | maintenance_tasks | DataPorter |
|--------|-------------------|------------|
| Purpose | One-off scripts | Import workflows |
| Preview before import | No | Yes |
| Visual validation | No | Yes (complete/partial/missing) |
| Multi-step workflow | No (fire & forget) | Yes (parse -> preview -> import) |
| Real-time progress | No | Yes (ActionCable) |
| Data sources | CSV, ActiveRecord | CSV, JSON, API (extensible) |
| Auto-generated UI | Parameter form | Dynamic column table |

The key difference: DataPorter adds a **human validation step** between parsing and persisting. The user sees exactly what will be imported, with clear status indicators for each row, before anything touches the database.

## Architecture overview

DataPorter is split into two clear layers:

```
┌─────────────────────────────────────┐
│  DataPorter (the gem)               │
│                                     │
│  Engine, Model, State Machine,      │
│  Sources, Orchestrator, Jobs,       │
│  ActionCable, UI, DSL, Registry,    │
│  Generators                         │
└──────────────┬──────────────────────┘
               │ mount + configure + define targets
┌──────────────┴──────────────────────┐
│  Host App                           │
│                                     │
│  Initializer, Target files,         │
│  Auth (parent controller),          │
│  Style overrides (optional)         │
└─────────────────────────────────────┘
```

The gem owns the infrastructure. The host app owns the business logic. This separation is the core design principle we'll follow throughout the series.

## The tech stack

Here's what we'll use and why:

| Dependency | Role | Why |
|------------|------|-----|
| **store_model** | Typed JSONB attributes | Store import records as structured data without extra tables |
| **phlex** | View components | Ruby-native views, easier to test and namespace than ERB |
| **turbo-rails** | Page updates | Turbo Frames for partial reloads during the import flow |
| **stimulus** | JS behavior | Progress bar updates via ActionCable |
| **Tailwind CSS** | Styling | Scoped with `dp-` prefix to avoid host app conflicts |

We'll also rely heavily on Rails built-ins: ActiveJob for background processing, ActionCable for real-time updates, ActiveStorage for file uploads, and enum-based state machine for the import lifecycle.

## What this series covers

Here's the roadmap — each part is a standalone article:

1. **Why build a data import engine?** (this article)
2. **Scaffolding a Rails Engine gem** — gem structure, Engine setup
3. **Configuration DSL** — making the gem flexible
4. **StoreModel & JSONB** — modeling import data without extra tables
5. **Target DSL** — one file = one import type
6. **CSV parsing with Sources** — the first end-to-end flow
7. **The Orchestrator** — coordinating parse and import
8. **ActionCable & Stimulus** — real-time progress
9. **Phlex & Tailwind UI** — auto-generated preview tables
10. **Controllers & routing** — engine controllers done right
11. **Generators** — install in one command
12. **JSON & API sources** — beyond CSV
13. **Testing a Rails Engine** — specs for an isolated engine
14. **Dry Run mode** — validate against the database before importing
15. **Publishing & retrospective** — from repo to rubygems.org

## Recap

- Data import is a recurring pattern in Rails apps that deserves a reusable solution
- DataPorter provides the infrastructure (upload, parse, preview, import) while the host app defines the business logic
- The 3-step workflow with human validation is what sets it apart from existing tools
- We're building a proper mountable Rails engine with a clean separation between gem and host app

## Next up

In the next article, we'll run `bundle gem data_porter`, set up the Rails Engine with `isolate_namespace`, structure our directories, and configure the gemspec with our dependencies. We'll make our first architectural decisions — and explain why they matter.

---

*This is part 1 of the series "Building DataPorter - A Data Import Engine for Rails". [Next: Scaffolding a Rails Engine gem](#)*
