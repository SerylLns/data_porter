---
title: "Building DataPorter #7 -- The Orchestrator: Coordinating the Import Workflow"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 7
tags: [ruby, rails, rails-engine, gem-development, orchestrator, activejob, error-handling]
published: false
---

# The Orchestrator: Coordinating the Import Workflow

> How to coordinate parsing, validation, and persistence through a single class that manages state transitions, handles errors per-record, and integrates with ActiveJob.

## Context

This is part 7 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 6](#), we built the DataImport model to track import state and the Source layer to parse CSV files into mapped hashes.

We now have all the individual pieces: targets describe imports, sources parse files, the RecordValidator checks column constraints, and DataImport tracks state. But nothing ties them together. In this article, we build the Orchestrator -- the class that coordinates the full parse-then-import workflow.

## The problem

Right now, if you wanted to run an import, you would need to manually resolve the source, call `fetch`, iterate over the rows, build ImportRecord objects, run validations, update the status, and handle failures. That is a lot of procedural logic. If it lived in a controller action, it would be untestable, unreusable, and impossible to run in the background. If it lived in the model, DataImport would become a god object. We need a dedicated coordination layer that knows the *order* of operations but delegates the *details* to the objects that own them.

## What we're building

Here is the Orchestrator in action -- two method calls that drive the entire workflow:

```ruby
# In a controller or job
orchestrator = DataPorter::Orchestrator.new(data_import, content: csv_string)

# Step 1: Parse the file, validate records, generate a preview
orchestrator.parse!
data_import.status   # => "previewing"
data_import.records  # => [ImportRecord, ImportRecord, ...]

# Step 2: After user reviews the preview, persist the records
orchestrator.import!
data_import.status   # => "completed"
data_import.report.imported_count  # => 42
```

Two methods, two phases. `parse!` turns raw data into validated records and stops at `previewing` so the user can review. `import!` takes the importable records and persists them through the target's `persist` method. If anything goes catastrophically wrong, the import transitions to `failed` with an error report.

## Implementation

### Step 1 -- The Orchestrator skeleton and parse phase

The Orchestrator is a plain Ruby object. It receives a DataImport and optional content (for testing), then delegates to the pieces we already built:

```ruby
# lib/data_porter/orchestrator.rb
class Orchestrator
  def initialize(data_import, content: nil)
    @data_import = data_import
    @target = data_import.target_class.new
    @source_options = { content: content }.compact
  end

  def parse!
    @data_import.parsing!
    records = build_records
    @data_import.update!(records: records, status: :previewing)
    build_report
  rescue StandardError => e
    handle_failure(e)
  end
end
```

The constructor instantiates the target (so we can call its hooks) and compacts the source options (so `content: nil` does not override ActiveStorage downloads). The `parse!` method follows a strict sequence: transition to `parsing`, build and validate records, save them with a `previewing` status, then generate a summary report. The `rescue` at the method level catches any failure -- a malformed CSV, a missing file, an unexpected source error -- and transitions the import to `failed` with the error message preserved in the report.

Notice that `parsing!` is called *before* the work starts. This is intentional: if the job crashes between the status transition and the `update!`, the import is left in `parsing` rather than `pending`, signaling to the user that something went wrong mid-process rather than silently sitting idle.

### Step 2 -- Building and validating records

The `build_records` method is where the Source, Target, and RecordValidator converge:

```ruby
# lib/data_porter/orchestrator.rb
def build_records
  source = @data_import.source_class.new(@data_import, **@source_options)
  raw_rows = source.fetch
  columns = @target.class._columns || []
  validator = RecordValidator.new(columns)

  raw_rows.each_with_index.map do |row, index|
    build_record(row, index, columns, validator)
  end
end

def build_record(row, index, columns, validator)
  record = StoreModels::ImportRecord.new(
    line_number: index + 1,
    data: extract_data(row, columns)
  )
  record = @target.transform(record)
  @target.validate(record)
  validator.validate(record)
  record.determine_status!
  record
end
```

Each row goes through a four-step pipeline: extract the data for declared columns, let the target transform it (e.g., normalizing phone numbers), let the target run custom validations, then run the generic column-level validations (required fields, type checks). Finally, `determine_status!` sets each record to `complete`, `partial`, or `missing` based on whether errors were added.

The RecordValidator handles the generic constraints we defined in the column DSL:

```ruby
# lib/data_porter/record_validator.rb
class RecordValidator
  def initialize(columns)
    @columns = columns
  end

  def validate(record)
    @columns.each do |col|
      value = record.data[col.name]
      validate_required(record, col, value)
      validate_type(record, col, value)
    end
  end
end
```

This separation matters: the target owns business-rule validations ("email must be unique in the system"), while the RecordValidator owns structural validations ("email must look like an email"). Neither knows about the other.

### Step 3 -- The import phase and per-record error handling

Once the user reviews the preview and confirms, `import!` persists the records:

```ruby
# lib/data_porter/orchestrator.rb
def import!
  @data_import.importing!
  results = import_records
  update_import_report(results)
  @target.after_import(results, context: build_context)
rescue StandardError => e
  handle_failure(e)
end

def persist_record(record, context, results)
  @target.persist(record, context: context)
  results[:created] += 1
rescue StandardError => e
  record.add_error(e.message)
  @target.on_error(record, e, context: context)
  results[:errored] += 1
end
```

The critical design decision here is the error boundary. Each record is persisted individually, and if `persist` raises -- a uniqueness violation, a foreign key constraint, a custom validation from the host app -- the error is captured *on that record* and the import continues. The import does not wrap everything in a single transaction. This means a 10,000-row file with 3 bad records will successfully import 9,997 records rather than rolling back the entire batch.

The `on_error` hook lets the target react to failures (logging, notifying, skipping related records), while `after_import` runs once after all records are processed, receiving the results hash for summary work like sending a confirmation email.

### Step 4 -- ActiveJob integration

The Orchestrator is designed to be called from anywhere, but its primary consumer is a pair of ActiveJob classes:

```ruby
# app/jobs/data_porter/parse_job.rb
class ParseJob < ActiveJob::Base
  queue_as { DataPorter.configuration.queue_name }

  def perform(import_id)
    data_import = DataImport.find(import_id)
    Orchestrator.new(data_import).parse!
  end
end

# app/jobs/data_porter/import_job.rb
class ImportJob < ActiveJob::Base
  queue_as { DataPorter.configuration.queue_name }

  def perform(import_id)
    data_import = DataImport.find(import_id)
    Orchestrator.new(data_import).import!
  end
end
```

Each job is a one-liner: find the import, delegate to the Orchestrator. The queue name comes from the engine's configuration, so the host app controls which queue processes imports. Because the Orchestrator already handles failures internally (transitioning to `failed` and recording the error), the jobs do not need their own error handling -- a crash at the ActiveJob level means something truly unexpected happened, and the adapter's retry mechanism takes over.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Coordination layer | Dedicated Orchestrator class | Controller-level logic or model callbacks | Keeps controllers thin, models focused on data, and the workflow independently testable |
| Transaction boundaries | Per-record persist (no wrapping transaction) | Single transaction around all records | A failed record should not roll back thousands of successful ones; partial success is more useful than total failure |
| Error recovery | Capture error on the record, continue importing | Halt on first error | Users expect to see which rows failed and why, not just "import failed"; the report becomes actionable |
| Two-phase workflow | Separate `parse!` and `import!` methods | A single `run!` method | The preview step between parse and import lets users catch problems before data hits the database |
| Job design | Thin jobs delegating to Orchestrator | Logic inside the job classes | The Orchestrator is testable without ActiveJob; jobs are just the async trigger |

## Testing it

The Orchestrator specs exercise both phases end-to-end using an anonymous target class and injected CSV content:

```ruby
# spec/data_porter/orchestrator_spec.rb
describe "#parse!" do
  it "transitions to previewing" do
    orchestrator = described_class.new(data_import, content: csv_content)

    orchestrator.parse!

    expect(data_import.reload.status).to eq("previewing")
  end

  it "validates required fields" do
    csv = "First Name,Last Name,Email\n,Smith,alice@example.com\n"
    orchestrator = described_class.new(data_import, content: csv)

    orchestrator.parse!

    record = data_import.reload.records.first
    expect(record.status).to eq("missing")
  end
end

describe "#import!" do
  it "handles per-record errors" do
    # Target that always raises on persist
    orchestrator = described_class.new(import)
    orchestrator.import!

    expect(import.reload.status).to eq("completed")
    expect(import.report.errored_count).to eq(1)
  end
end
```

The key pattern: even when every `persist` call raises, the import still reaches `completed` -- not `failed`. The `failed` status is reserved for catastrophic errors (the source cannot be read, the target cannot be resolved). Per-record errors are expected operational noise, tracked in the report.

## Recap

- The **Orchestrator** is a plain Ruby class that coordinates the parse-validate-persist workflow, keeping controllers thin and models focused.
- The **two-phase design** (`parse!` then `import!`) creates a natural preview checkpoint where users can review data before it touches the database.
- **Per-record error handling** means a single bad row never takes down the entire import; errors are captured on individual records and surfaced in the report.
- **ActiveJob integration** is a thin wrapper: two one-liner jobs that delegate to the Orchestrator, using the engine's configured queue name.

## Next up

The import now runs in the background, but the user has no way to know what is happening. They click "Import" and stare at a static page. In part 8, we build a **real-time progress system** using ActionCable and Stimulus -- a Broadcaster service that pushes status updates and record counts to the browser as the Orchestrator processes each row. No more refreshing to check if it is done.

---

*This is part 7 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Parsing CSV Data with Sources](#) | [Next: Real-time Progress with ActionCable & Stimulus](#)*
