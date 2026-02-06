---
title: "Building DataPorter #4 — Modeling import data with StoreModel & JSONB"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 4
tags: [ruby, rails, rails-engine, gem-development, store-model, jsonb, data-modeling]
published: false
---

# Modeling import data with StoreModel & JSONB

> Storing structured import records, errors, and reports inside a single JSONB column -- no extra tables, no schema sprawl.

## Context

This is part 4 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 3](#), we built the configuration DSL that lets host apps customize the gem through a clean `configure` block.

Now we shift from *how the gem behaves* to *what it operates on*: the data models for parsed records, validation errors, and summary reports. We'll model all three using the StoreModel gem and PostgreSQL JSONB columns.

## The problem

A typical import engine ends up with a lot of tables: imports, import rows, import errors, reports. Each needs a migration, foreign keys, indexes, and cleanup logic. For a gem that drops into any Rails app, that's a heavy footprint.

But these records are ephemeral. They exist during the import workflow, get consulted in the results view, and nobody queries them independently. You never ask "give me all errors across all imports." They're always accessed through their parent.

If the data is always read and written as a group, it doesn't need its own table. It needs a structured column.

## What we're building

A single `DataImport` record will carry its entire import payload in JSONB columns:

```ruby
# Anywhere in the engine
import = DataPorter::DataImport.find(42)

import.report.records_count      # => 150
import.report.errored_count      # => 3
import.report.error_reports.each { |e| puts e.message }

import.records.first.line_number  # => 1
import.records.first.status       # => "complete"
import.records.first.data         # => { "name" => "Alice", "email" => "alice@example.com" }
```

No joins, no N+1 queries. Records and reports come back as typed Ruby objects with real attributes and methods -- not raw hashes.

## Implementation

### Step 1 -- The Error model

Every import record can accumulate validation errors. We need a small object to represent each one. StoreModel lets us define it like an ActiveModel attribute model, but serialized into JSON.

```ruby
# lib/data_porter/store_models/error.rb
module DataPorter
  module StoreModels
    class Error
      include StoreModel::Model

      attribute :message, :string
    end
  end
end
```

`include StoreModel::Model` gives us ActiveModel-compatible attributes that serialize to and from JSON. Why not a plain hash? Because `error.message` is a method call with autocompletion, not `error["message"]` where you guess at indifferent access. If we need `:code` or `:severity` later, we add an attribute and existing data deserializes cleanly -- new fields default to nil.

### Step 2 -- The ImportRecord model

Each row from the source file becomes an `ImportRecord`. This is the workhorse of the import: it holds the parsed data, tracks validation status, and collects errors and warnings.

```ruby
# lib/data_porter/store_models/import_record.rb
module DataPorter
  module StoreModels
    class ImportRecord
      include StoreModel::Model

      attribute :line_number, :integer
      attribute :status, :string, default: "pending"
      attribute :data, default: -> { {} }
      attribute :errors_list, Error.to_array_type, default: -> { [] }
      attribute :warnings, Error.to_array_type, default: -> { [] }
      attribute :target_id, :integer
      attribute :dry_run_passed, :boolean, default: false
    end
  end
end
```

The `data` attribute stores whatever hash the source parser produces -- no explicit type, because each import target defines different columns. The lambda defaults (`-> { {} }`) are critical; without them, every record shares the same mutable object. `Error.to_array_type` makes `errors_list` a typed array: each JSON entry deserializes into an `Error` instance, not a raw hash.

The model also carries behavior. Status determination runs after validation:

```ruby
# lib/data_porter/store_models/import_record.rb
def determine_status!
  self.status = if required_error?
                  "missing"
                elsif errors_list.any?
                  "partial"
                else
                  "complete"
                end
end
```

Three statuses: "missing" (a required field is absent -- the record cannot be imported), "partial" (optional field errors exist -- the record can be imported with warnings), and "complete" (clean row, ready to go). The Orchestrator will call `determine_status!` after validation and use `importable?` to decide which records to persist.

### Step 3 -- The Report model

After parsing and validating, we need a summary. The Report model aggregates counts and collects top-level errors (like "file has no header row" or "unexpected encoding").

```ruby
# lib/data_porter/store_models/report.rb
module DataPorter
  module StoreModels
    class Report
      include StoreModel::Model

      attribute :records_count, :integer, default: 0
      attribute :complete_count, :integer, default: 0
      attribute :partial_count, :integer, default: 0
      attribute :missing_count, :integer, default: 0
      attribute :duplicate_count, :integer, default: 0
      attribute :imported_count, :integer, default: 0
      attribute :errored_count, :integer, default: 0
      attribute :error_reports, Error.to_array_type, default: []
    end
  end
end
```

Every counter defaults to zero; the Orchestrator increments them during processing. `error_reports` reuses `Error.to_array_type` for import-level errors that don't belong to a specific row -- same typed-array pattern as `ImportRecord#errors_list`, so the UI can render both with the same component.

### Step 4 -- TypeValidator: validating before the database

StoreModel handles serialization. But we also need to validate *values* before they reach the model -- does "abc" pass as an integer? Is "not-a-date" a valid date? The TypeValidator module handles this at the column level, before the data ever touches ActiveRecord.

```ruby
# lib/data_porter/type_validator.rb
module DataPorter
  module TypeValidator
    VALIDATORS = {
      string:   ->(_value, _opts) { true },
      integer:  ->(value, _opts) { Integer(value, exception: false) },
      decimal:  ->(value, _opts) { Float(value, exception: false) },
      date:     ->(value, opts) { parse_date(value, opts) },
      email:    ->(value, _opts) { value.match?(/\A[^@\s]+@[^@\s]+\z/) },
      phone:    ->(value, _opts) { value.match?(/\A[+\d][\d\s\-().]{6,}\z/) },
      url:      ->(value, _opts) { valid_url?(value) },
      boolean:  ->(value, _opts) { %w[true false 1 0].include?(value.to_s.downcase) }
    }.freeze
  end
end
```

Each type maps to a lambda that returns truthy or falsy. The public API is one method: `TypeValidator.valid?("42", :integer)`. Integers use `Integer()` with `exception: false` to avoid rescue-driven control flow. Dates support an optional `:format` option for regional formatting like `"%d/%m/%Y"`.

The key design choice: validation happens *before* data enters the StoreModel. During parsing, the source reads a row, column definitions declare expected types, and the validator checks each value. Errors get added to the ImportRecord via `add_error`. By the time `determine_status!` runs, all column-level issues are captured.

This is deliberately separate from database-level validation (uniqueness, foreign keys), which runs later during the actual import. Keeping the two layers apart lets us show users a preview with type errors highlighted before any write attempt -- the foundation for the dry-run feature in part 14.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Row storage | JSONB column (array of StoreModel) | Separate `import_rows` table | Records are always accessed through their parent; no independent queries needed. One fewer migration for host apps to manage |
| Structured JSON | StoreModel gem | Hand-rolled `serialize` / raw hashes | StoreModel gives us ActiveModel attributes, typed arrays, defaults, and validations. Writing our own serializer would duplicate all of that |
| Validation layer | Column-level TypeValidator + later DB-level | Database-only validation | Enables preview and dry-run without touching the database. Users see type errors immediately, before any write attempt |
| Error representation | StoreModel class with `:message` | Plain strings in an array | Extensible -- we can add `:code`, `:severity`, `:column` later without changing the array structure or breaking existing serialized data |
| Status logic | Method on ImportRecord (`determine_status!`) | External service or state machine gem | Status depends only on the record's own errors. No transitions or events needed. A method is the simplest thing that works |

## Testing it

ImportRecord specs verify status determination:

```ruby
# spec/data_porter/store_models/import_record_spec.rb
RSpec.describe DataPorter::StoreModels::ImportRecord do
  subject(:record) { described_class.new(line_number: 1, data: { name: "Alice" }) }

  describe "#determine_status!" do
    it "sets missing when required field error exists" do
      record.add_error("Name is required")
      record.determine_status!
      expect(record.status).to eq("missing")
    end

    it "sets partial when non-required error exists" do
      record.add_error("Email: invalid email")
      record.determine_status!
      expect(record.status).to eq("partial")
    end

    it "sets complete when no errors" do
      record.determine_status!
      expect(record.status).to eq("complete")
    end
  end
end
```

TypeValidator specs cover each type, including edge cases like custom date formats:

```ruby
# spec/data_porter/type_validator_spec.rb
RSpec.describe DataPorter::TypeValidator do
  it "accepts valid integers" do
    expect(described_class.valid?("42", :integer)).to be true
  end

  it "rejects non-integers" do
    expect(described_class.valid?("abc", :integer)).to be false
  end

  it "accepts dates with custom format" do
    expect(described_class.valid?("15/01/2024", :date, format: "%d/%m/%Y")).to be true
  end
end
```

No database setup needed for any of these. StoreModel objects instantiate in memory like plain Ruby objects, which makes the specs fast and isolated.

## Recap

- **JSONB columns** let us store structured import data (records, errors, reports) without extra tables. The data is always accessed through the parent import, so a separate table would add complexity with no query benefit.
- **StoreModel** turns those JSONB columns into proper Ruby objects with typed attributes, defaults, and methods. `Error.to_array_type` gives us typed arrays that serialize and deserialize automatically.
- **ImportRecord** is the core unit of work: it holds a parsed row, collects errors and warnings, and determines its own status based on the errors it carries.
- **TypeValidator** handles column-level validation before the database, enabling the preview and dry-run features. Each type is a lambda in a hash -- easy to extend, easy to test.

## Next up

We have configuration (part 3) and data models (this part). In part 5, we'll bring them together by designing the **Target DSL** -- the class-level interface that lets each import type declare its label, model, columns, and CSV mapping in a single file. One file per import type, zero boilerplate. If you've ever wanted `class_attribute` to do more heavy lifting, that's the one.

---

*This is part 4 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Configuration DSL](#) | [Next: Designing a Target DSL](#)*
