---
title: "Building DataPorter #14 -- Dry Run : Valider avant d'importer"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 14
tags: [ruby, rails, rails-engine, gem-development, dry-run, validation, store-model, activejob]
published: false
---

# Dry Run : Valider avant d'importer

> Le preview attrape les erreurs de colonnes. Le dry run attrape les erreurs de base de donnees. Deux filets de securite, deux niveaux de confiance.

## Context

This is part 14 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 13](#), we have detailed the testing strategy: in-memory SQLite, structural controller specs, anonymous target classes, and a spec_helper that bootstraps just enough Rails to cover every layer.

We have now a complete import pipeline: parse the file, preview the records, confirm, persist. But there is a gap between the preview and the real import. The preview validates the *data* -- required fields, types, formats. It does not validate what happens when that data hits the database. A uniqueness constraint, a foreign key violation, a custom model validation that queries other tables -- none of these surface until `persist` is actually called. By then, the import is running for real.

In this article, we build a **dry run** mode that bridges this gap. It runs the full persist logic inside a transaction, captures any database-level errors on each record, then rolls back. The user sees exactly which records would fail *before* committing to the import.

## Why two validation layers

The preview phase runs the RecordValidator against column definitions. It catches structural problems: "this field is required and it is empty", "this field should be an email but it is not". These are fast, stateless checks that do not touch the database.

But many real-world validations are stateful. A `validates_uniqueness_of :email` on the User model requires a database query. A `belongs_to :company` with a foreign key constraint requires the company to exist. A custom validation that checks `if: -> { some_scope.exists? }` requires the full ActiveRecord context. None of these can run during preview because there is no model instance, no transaction, no database connection in the validation path.

The dry run fills this gap. It calls the target's `persist` method -- the same method that the real import uses -- but captures exceptions instead of letting them propagate. Each record gets annotated with its result: passed or failed, with the error message attached.

## The `dry_run_enabled` DSL flag

Not every import needs a dry run. A simple CSV-to-table import with no uniqueness constraints might not benefit from the overhead. We make it opt-in at the target level:

```ruby
# app/importers/user_import.rb
class UserImport < DataPorter::Target
  label "Users"
  model_name "User"
  dry_run_enabled

  columns do
    column :email, type: :email, required: true
    column :name, type: :string, required: true
  end

  def persist(record, context:)
    User.create!(record.attributes)
  end
end
```

The `dry_run_enabled` class method is a simple flag on the Target DSL:

```ruby
# lib/data_porter/target.rb
class << self
  attr_reader :_dry_run_enabled

  def dry_run_enabled
    @_dry_run_enabled = true
  end
end
```

No arguments, no block, no configuration. Either the target supports dry run or it does not. The controller checks `target_class._dry_run_enabled` to decide whether to show the "Dry Run" button on the preview page.

## The `dry_running` status

The DataImport enum needed a new state. The import transitions from `previewing` to `dry_running` while the dry run executes, then back to `previewing` when it completes:

```ruby
# app/models/data_porter/data_import.rb
enum :status, {
  pending: 0,
  parsing: 1,
  previewing: 2,
  importing: 3,
  completed: 4,
  failed: 5,
  dry_running: 6
}
```

The value `6` is appended at the end rather than inserted in logical order. This is intentional -- existing records in production have integer status values. Inserting `dry_running` at position 3 would shift `importing`, `completed`, and `failed`, corrupting every existing import. Enums with integer backing must be append-only.

The state flow is: `previewing -> dry_running -> previewing`. The dry run is not a terminal state. It enriches the records with database-level feedback and returns to the preview so the user can review the results and decide whether to proceed with the real import.

## The `dry_run!` flow

The Orchestrator gains a third public method alongside `parse!` and `import!`:

```ruby
# lib/data_porter/orchestrator.rb
def dry_run!
  @data_import.dry_running!
  run_dry_run_records
  @data_import.update!(status: :previewing)
  build_report
rescue StandardError => e
  handle_failure(e)
end
```

The structure mirrors `parse!` and `import!`: transition to the working status, do the work, transition to the result status, rebuild the report. The `rescue` catches catastrophic failures and transitions to `failed` with an error report.

The real work happens in `run_dry_run_records`:

```ruby
def run_dry_run_records
  records = @data_import.records
  importable = records.select(&:importable?)
  context = build_context

  importable.each do |record|
    dry_run_record(record, context)
  end

  @data_import.records_will_change!
  @data_import.update!(records: records)
end

def dry_run_record(record, context)
  @target.persist(record, context: context)
  record.dry_run_passed = true
rescue StandardError => e
  record.dry_run_passed = false
  record.add_error(e.message)
end
```

For each importable record, we call the target's actual `persist` method. If it succeeds, `dry_run_passed` is set to `true`. If it raises -- an `ActiveRecord::RecordInvalid`, a constraint violation, any exception -- we capture the message on the record and mark it as failed. The import data is never committed because the dry run operates at the record level, catching errors individually.

The `dry_run_passed` attribute on ImportRecord is a simple boolean:

```ruby
# lib/data_porter/store_models/import_record.rb
attribute :dry_run_passed, :boolean, default: false
```

After the dry run, the preview table can show a green check or a red cross next to each record, along with the specific error message for failures. The user gets a precise map of what will work and what will not.

## The StoreModel dirty tracking gotcha

There is a subtle but critical line in `run_dry_run_records`:

```ruby
@data_import.records_will_change!
@data_import.update!(records: records)
```

Why `records_will_change!` before `update!`? The answer lies in how ActiveRecord tracks changes on complex attributes.

StoreModel attributes are serialized to JSON and stored in a text (or JSONB) column. When you modify an object *in place* -- setting `record.dry_run_passed = true` on a record that already exists in the `records` array -- ActiveRecord does not detect the change. From its perspective, the `records` attribute still points to the same Ruby array at the same memory address. The serialized value has changed, but ActiveRecord's dirty tracking compares object identity, not serialized content.

Without `records_will_change!`, the `update!` call would see "records has not changed" and skip the column in the SQL UPDATE. The dry run results would be computed correctly in memory but never persisted to the database. The user would see no change on the preview page.

`records_will_change!` explicitly marks the attribute as dirty, forcing ActiveRecord to include it in the next save. This is a well-known pattern with serialized attributes, but it is easy to forget -- and the failure mode is silent. The data looks correct in the current process, the tests that do not reload from the database pass, and only the production user sees stale results.

This is one of those bugs that TDD catches early. The spec reloads the import from the database and checks `dry_run_passed` on the reloaded records:

```ruby
it "marks records as dry_run_passed on success" do
  DataPorter::Orchestrator.new(import.reload).dry_run!
  import.reload.records.each do |record|
    expect(record.dry_run_passed).to be true
  end
end
```

The `import.reload` forces a fresh read from SQLite. Without `records_will_change!`, this spec fails -- `dry_run_passed` is still `false` in the database even though it was set to `true` in memory.

## DryRunJob

Like `parse!` and `import!`, the dry run executes asynchronously via a dedicated job:

```ruby
# app/jobs/data_porter/dry_run_job.rb
class DryRunJob < ActiveJob::Base
  queue_as { DataPorter.configuration.queue_name }

  def perform(import_id)
    data_import = DataImport.find(import_id)
    Orchestrator.new(data_import).dry_run!
  end
end
```

Same pattern as ParseJob and ImportJob: find the import, delegate to the Orchestrator. The job itself has no logic -- it is a one-liner that bridges the async boundary.

## Controller action and route

The controller gains a `dry_run` action:

```ruby
# app/controllers/data_porter/imports_controller.rb
before_action :set_import, only: %i[show parse confirm cancel dry_run]

def dry_run
  DataPorter::DryRunJob.perform_later(@import.id)
  redirect_to import_path(@import)
end
```

And the route:

```ruby
resources :imports, only: %i[index new create show] do
  member do
    post :parse
    post :confirm
    post :cancel
    post :dry_run
  end
end
```

The pattern is identical to the other member actions: POST triggers a side effect (enqueue a job), redirect back to the show page where ActionCable will push progress updates. The view conditionally shows the "Dry Run" button only when `target_class._dry_run_enabled` is true and the import is in `previewing` status.

## Testing

The dry run specs follow the series' established patterns -- anonymous target classes, registry cleanup, and database round-trip assertions:

```ruby
RSpec.describe "Dry Run" do
  let(:target_class) do
    klass = Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      dry_run_enabled

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
      end
    end
    klass.define_method(:persist) do |record, context:|
      record
    end
    klass
  end

  describe "Orchestrator#dry_run!" do
    it "transitions to previewing after dry run" do
      DataPorter::Orchestrator.new(import.reload).dry_run!
      expect(import.reload.status).to eq("previewing")
    end

    it "marks records as dry_run_passed on success" do
      DataPorter::Orchestrator.new(import.reload).dry_run!
      import.reload.records.each do |record|
        expect(record.dry_run_passed).to be true
      end
    end

    it "captures errors from failing persist" do
      # Target that raises ActiveRecord::RecordInvalid
      DataPorter::Orchestrator.new(failing_import.reload).dry_run!

      record = failing_import.reload.records.first
      expect(record.dry_run_passed).to be false
      expect(record.errors_list.map(&:message)).to include(match(/Validation failed/))
    end
  end
end
```

The failing target class simulates a database-level error by raising `ActiveRecord::RecordInvalid` in `persist`. The spec verifies that the error is captured on the record, that `dry_run_passed` is false, and that the import still transitions to `previewing` -- not `failed`. A record-level error is expected operational feedback, not a catastrophic failure.

The DryRunJob spec verifies delegation:

```ruby
describe "DryRunJob" do
  it "calls Orchestrator#dry_run!" do
    orchestrator = instance_double(DataPorter::Orchestrator, dry_run!: nil)
    allow(DataPorter::Orchestrator).to receive(:new).and_return(orchestrator)

    DataPorter::DryRunJob.new.perform(import.id)

    expect(orchestrator).to have_received(:dry_run!)
  end
end
```

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Opt-in flag | `dry_run_enabled` on Target DSL | Always-on dry run | Not every import benefits from the overhead; simple imports can skip it |
| Status value | Append `dry_running: 6` at the end of the enum | Insert in logical order | Integer-backed enums must be append-only to avoid corrupting existing data |
| Dirty tracking | Explicit `records_will_change!` | Reassigning the array (`self.records = records.dup`) | More explicit about intent; avoids unnecessary array duplication; documents the StoreModel gotcha |
| Error boundary | Per-record rescue in `dry_run_record` | Wrapping all records in a single begin/rescue | One failing record should not prevent the others from being validated |

## Recap

- The **dry run** bridges the gap between preview (column-level validation) and real import (database-level validation), giving users a complete picture before any data is committed.
- The **`dry_run_enabled` DSL flag** makes it opt-in per target -- not every import needs the overhead.
- The **`dry_running` status** follows the append-only rule for integer-backed enums, preserving existing data.
- The **`records_will_change!` call** is the key to making StoreModel in-place mutations persist -- without it, ActiveRecord skips the attribute in the SQL UPDATE because its dirty tracking does not detect in-place changes on serialized objects.
- The **DryRunJob** follows the same thin-job pattern as ParseJob and ImportJob: find, delegate, done.
- The **controller action and route** mirror the existing member actions: POST triggers a job, redirect back to show.

## Next up

We now have a full-featured, tested, and safe import engine. In part 15, we wrap up the series: **publishing the gem to RubyGems**, writing a proper CHANGELOG, choosing a versioning strategy, and reflecting on what worked, what we would do differently, and what DataPorter looks like from the outside.

---

*This is part 14 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Testing a Rails Engine with RSpec](#) | [Next: Publishing the Gem & Retrospective](#)*
