---
title: "Building DataPorter #17 -- Showcase & Final Retrospective"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 17
tags: [ruby, rails, rails-engine, gem-development, retrospective, showcase, open-source]
published: false
---

# Showcase & Final Retrospective

> 17 articles, 22 components, one complete gem. Here is DataPorter in action -- and what this series taught me about building Rails engines.

## Context

This is the final article in the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 16](#), we connected the last pieces -- ERB view templates composing Phlex components into full pages, a CSS stylesheet, and the ActiveStorage file attachment.

DataPorter is now feature-complete. Every layer works: the DSL defines import targets, the sources parse files, the orchestrator coordinates the workflow, ActionCable pushes progress in real time, Phlex components render the UI, and ERB templates tie it all together. In this article, we walk through the full workflow in a real application, then look back at the entire series.

## DataPorter in action

### Installation

A host app gets DataPorter running in three commands:

```bash
bundle add data_porter
rails generate data_porter:install
rails db:migrate
```

The install generator creates everything: the migration for the `data_porter_imports` table, an initializer with sensible defaults, the route mount, and an empty `app/importers/` directory for target classes.

### Defining a target

One file, one import type. Here is a target that imports contacts from a CSV:

```ruby
# app/importers/contact_target.rb
class ContactTarget < DataPorter::Target
  label "Importer Contact"
  model_name "Contact"
  icon "fas fa-file-import"
  sources :csv

  columns do
    column :name,         type: :string, required: true
    column :email,        type: :string
    column :phone_number, type: :string
    column :address,      type: :string
    column :room,         type: :string
  end

  def persist(record, context:)
    Contact.create!(record.attributes)
  end
end
```

A few lines of DSL, one method. The target declares its columns, marks which are required, and defines how each record is persisted. Everything else -- parsing, validation, progress tracking, UI rendering -- is handled by the engine.

### The workflow

**Step 1: Create a new import**

The user visits `/imports`, clicks "New Import", and a modal opens. They select the target, choose the source type, drag and drop a file onto the dropzone, and click "Start Import".

![New Import modal with target dropdown, source type select, and dropzone file upload](../screenshots/modal-new-import.jpg)

**Step 2: Parsing and preview**

The ParseJob runs in the background. ActionCable pushes progress to the browser via the Stimulus-powered progress bar. When parsing completes, the import transitions to `previewing` and the page shows:

- **Summary cards**: 14 ready, 0 incomplete, 1 missing, 0 duplicates
- **Preview table**: every row with its status, data, and any errors highlighted

![Preview page with summary cards and preview table showing record statuses](../screenshots/preview.jpg)

The user sees exactly what will happen before anything touches the database.

**Step 3: Dry run (optional)**

For targets that enable it, a "Dry Run" button appears. Clicking it runs every record through the actual `persist` method inside a transaction, captures any database-level errors (uniqueness violations, foreign key constraints), then rolls back. The preview table updates with a green check or red cross for each record.

**Step 4: Confirm and import**

The user clicks "Confirm Import". The ImportJob processes each importable record, calling the target's `persist` method for real this time. Progress updates flow through ActionCable. When it finishes, the results summary shows the final counts.

**Step 5: Track all imports**

The index page lists every import with its status badge. At a glance, the user sees what completed, what failed, and what is still in preview.

![Index page listing imports with colored status badges](../screenshots/index-with-previewing.jpg)

## The architecture at a glance

```
Host App                          DataPorter Engine
---------                         -----------------
app/importers/                    lib/data_porter/
  contact_target.rb                 target.rb (DSL)
                                    registry.rb (discovery)
config/initializers/                configuration.rb (config)
  data_porter.rb
                                  app/models/
                                    data_import.rb (state + storage)

                                  lib/data_porter/sources/
                                    csv.rb, json.rb, api.rb

                                  lib/data_porter/
                                    orchestrator.rb (parse/import/dry_run)
                                    record_validator.rb (type checks)
                                    broadcaster.rb (ActionCable)

                                  app/jobs/
                                    parse_job.rb, import_job.rb, dry_run_job.rb

                                  lib/data_porter/components/
                                    status_badge.rb, summary_cards.rb,
                                    preview_table.rb, progress_bar.rb,
                                    results_summary.rb, failure_alert.rb

                                  app/views/data_porter/imports/
                                    index.html.erb, new.html.erb, show.html.erb

                                  app/assets/stylesheets/
                                    data_porter/application.css
```

The host app provides a Target file and an initializer. The engine provides everything else. The boundary is clean: business logic lives in the Target, infrastructure lives in the engine.

## What the series built

| # | Article | Component |
|---|---------|-----------|
| 1 | Why build a data import engine? | Motivation, problem statement |
| 2 | Scaffolding a Rails Engine gem | Engine, isolate_namespace |
| 3 | Configuration DSL | `DataPorter.configure`, defaults |
| 4 | StoreModel & JSONB | ImportRecord, Error, Report |
| 5 | Target DSL | `label`, `columns`, `persist` |
| 6 | Parsing CSV sources | Source::CSV, ActiveStorage |
| 7 | The Orchestrator | parse!, import!, error handling |
| 8 | ActionCable & Stimulus | Broadcaster, ImportChannel, progress bar |
| 9 | Phlex UI components | 7 components, dp- prefix |
| 10 | Controllers & Routing | ImportsController, engine routes |
| 11 | Generators | Install + Target generators |
| 12 | JSON & API sources | Source::JSON, Source::API |
| 13 | Testing a Rails Engine | spec_helper, structural specs |
| 14 | Dry Run | Transaction rollback, enrichment |
| 15 | Publishing & Retrospective | Gemspec, versioning, lessons |
| 16 | ERB View Templates | ERB + Phlex composition, CSS |
| 17 | Showcase & Final Retro | This article |

17 articles. Each one with real code, tests, and an explained decision. Not a theoretical tutorial -- a working gem, built step by step.

## The numbers

```
Specs:    221 examples, 0 failures
Rubocop:  80 files, 0 offenses
Runtime:  < 1 second (full suite)
```

221 specs covering every layer: models, store models, sources, orchestrator, jobs, channels, Phlex components, controllers, routes, generators, views. Everything runs on in-memory SQLite, without a dummy app, in under a second.

## Reflecting on the approach

### TDD on a gem: the right trade-off

The red-green-refactor cycle was applied strictly on every feature. Writing specs first forces you to define the API before the implementation. It feels slow at first -- you write code that does not even compile. But it shortens the total cycle because API decisions are made once, not three times.

The trap: TDD does not replace integration tests in the host app. The gem's specs verify that each component works in isolation. They do not verify that the whole thing works with the real app config, real models, and real middleware. The gem tests its wiring. The host app tests its behavior. Both are necessary.

### Rails 8 and engines: the surprises

Rails 8 changed subtle things for engines:

**`ActionView::Base`** refuses to be instantiated directly. You must go through `with_empty_template_cache`. This is not documented anywhere in the Rails guides -- you discover it when the test raises `NotImplementedError`.

**`belongs_to` required by default** applies even when you do not call `initialize!` in older tests. But as soon as you bootstrap a real Rails app (necessary for ActiveStorage), the validation activates and breaks all tests that create a DataImport with `user_type: "User", user_id: 1` without having a real User in the database. The solution: `optional: true` on the association.

**Engine URL helpers** require the engine's controller (not a generic `ActionController::Base`) to resolve routes. The view delegates `_routes` to its controller. If the controller does not have the engine's routes, `import_path` raises a cryptic error about `data_porter_path`.

### Phlex without phlex-rails: it works

The choice not to depend on phlex-rails was deliberate. Each component is a pure Ruby object in `lib/`. You render it with `.call`. You test it with `.call`. You integrate it in ERB with `raw component.call`. No magic helpers, no template resolution, no conflicts with the host app's view system.

The cost: each call is a bit verbose. `<%= raw DataPorter::Components::StatusBadge.new(status: @import.status).call %>` is longer than `<%= render StatusBadge.new(status: @import.status) %>`. But clarity is worth the trade-off. When reading the template, you know exactly what is happening.

### Plain CSS stylesheet: underrated

No Tailwind build, no PostCSS, no Sass. One CSS file with `dp-` prefixed classes and CSS custom properties for theming. It works on any Rails app, whether the host uses Sprockets, Propshaft, or importmap. No configuration, no compatibility to manage.

The `dp-` prefix prevents collisions. The host app can override any class via the CSS custom properties (`--dp-primary`, `--dp-danger`, etc.) or ignore the stylesheet entirely and provide its own. The convention is simple and sufficient.

## What is next?

DataPorter 0.1.0 covers the complete workflow: upload, parse, preview, dry run, import. Here are ideas for future versions:

**Batch imports** -- For files with 100k+ rows, `insert_all` in batches instead of `create!` per record. This requires rethinking the `persist` contract.

**Turbo Streams** -- Replace the full page reload after a status change with targeted Turbo Stream updates. The show template could update itself without reloading.

**Export** -- The reverse path. If we can parse and validate records, we can also serialize them. The Target already has all the necessary information.

**Dashboard** -- An overview page with aggregated stats: imports per day, error rate, average processing time. The data is already in the `data_porter_imports` table.

## Final words

DataPorter was born from a simple observation: we rebuild the same import workflow in every Rails app. 17 articles later, it is a published gem with a clean DSL, a complete UI, and 221 tests.

The method -- strict TDD, one article per feature, documented decisions -- forces you to build something solid. No shortcuts, no "we will see later". Each component exists because a test requires it, and each test exists because a need was identified.

The result: one `bundle add data_porter`, one generator, a Target of 15 lines, and any Rails app has a complete import system with preview, real-time validation, dry run, and live progress.

That was the plan. It took 17 articles to get there. And it was worth it.

---

*This is part 17 and the final article of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: ERB View Templates](#)*
