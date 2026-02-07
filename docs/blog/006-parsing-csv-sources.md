---
title: "Building DataPorter #6 — Parsing CSV Data with Sources"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 6
tags: [ruby, rails, rails-engine, gem-development, csv, active-storage, source-pattern]
published: false
---

# Parsing CSV Data with Sources

> How to model an import record in the database, parse CSV files through a pluggable Source layer, and map headers to target columns -- the first end-to-end flow.

## Context

This is part 6 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 5](#), we designed the Target DSL and Registry -- the layer that describes *what* an import looks like: its columns, mappings, and persistence logic.

Now we need the other half: the code that represents an import *in progress* and the code that reads raw data from a file. By the end of this article, we will have a `DataImport` ActiveRecord model to track state, a `Source` abstraction for parsing, and a concrete CSV source that maps headers to target columns. This is where data first flows through the engine.

## The problem

A target declaration tells the engine what columns to expect, but it says nothing about where data comes from or how to track the import lifecycle. We need a database-backed model that records who started the import, what state it is in, what records were parsed, and what errors occurred. We also need a layer that can read a CSV file (today) and a JSON payload or API response (later) through the same interface. Without this separation, the parsing logic would live in the controller or the target itself, coupling the format to the business rules.

## What we're building

Here is the end-to-end flow we are wiring together:

```ruby
# 1. Create an import record
import = DataPorter::DataImport.create!(
  target_key: "guests",
  source_type: "csv",
  user: current_user
)

# 2. Resolve the source and parse the file
source_class = DataPorter::Sources.resolve(import.source_type)
source = source_class.new(import, content: csv_string)
rows = source.fetch
# => [{ first_name: "Alice", last_name: "Smith", email: "alice@example.com" }, ...]

# 3. The import knows its target
import.target_class
# => GuestTarget
```

Three objects, three concerns: `DataImport` tracks state, `Sources.resolve` picks the parser, and the source turns raw bytes into mapped hashes. The Orchestrator (part 7) will coordinate these pieces, but each works independently.

## Implementation

### Step 1 -- The DataImport model and migration

The `DataImport` model is the central record for every import. It needs to track which target is being imported, what source format the data arrives in, what state the import has reached, and who initiated it.

The migration creates a single table with JSONB columns for records and report data (the StoreModel types from part 4):

```ruby
# lib/generators/data_porter/install/templates/create_data_porter_imports.rb.erb
create_table :data_porter_imports do |t|
  t.string  :target_key,  null: false
  t.string  :source_type, null: false, default: "csv"
  t.integer :status,      null: false, default: 0
  t.jsonb   :records,     null: false, default: []
  t.jsonb   :report,      null: false, default: {}
  t.jsonb   :config,      null: false, default: {}

  t.references :user, polymorphic: true, null: false

  t.timestamps
end
```

The `user` reference is polymorphic (`user_type` + `user_id`), so the engine works regardless of whether the host app calls its user model `User`, `AdminUser`, or `Account`. The `config` JSONB column stores source-specific options like CSV delimiters or API authentication parameters -- things that vary per import, not per target.

The model itself is compact:

```ruby
# app/models/data_porter/data_import.rb
class DataImport < ActiveRecord::Base
  self.table_name = "data_porter_imports"

  belongs_to :user, polymorphic: true

  enum :status, {
    pending: 0, parsing: 1, previewing: 2,
    importing: 3, completed: 4, failed: 5
  }

  attribute :records, StoreModels::ImportRecord.to_array_type, default: -> { [] }
  attribute :report, StoreModels::Report.to_type, default: -> { StoreModels::Report.new }
  attribute :config, :json, default: -> { {} }

  validates :target_key, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[csv json api] }
end
```

The `status` enum defines the import lifecycle as a linear state machine: `pending -> parsing -> previewing -> importing -> completed` (or `failed` at any point). Integer-backed enums keep the database column small and indexable. The `records` and `report` attributes use StoreModel types that we built in part 4 -- they serialize structured data into the JSONB columns while providing typed Ruby objects in memory.

Two convenience methods bridge the model to the rest of the engine:

```ruby
# app/models/data_porter/data_import.rb
def target_class
  Registry.find(target_key)
end

def importable_records
  records.select(&:importable?)
end
```

`target_class` delegates to the Registry so any code holding a `DataImport` can reach the target's column definitions, mappings, and hooks. `importable_records` filters parsed records down to those that passed validation -- the subset the Orchestrator will actually persist.

### Step 2 -- The Source base class

Sources are responsible for one thing: turning raw input into an array of hashes where keys are target column names. The base class defines the interface and the shared mapping logic:

```ruby
# lib/data_porter/sources/base.rb
module DataPorter
  module Sources
    class Base
      def initialize(data_import, **)
        @data_import = data_import
        @target_class = data_import.target_class
      end

      def fetch
        raise NotImplementedError
      end
    end
  end
end
```

Every source receives the `DataImport` record at construction, which gives it access to the target class (for column mappings) and the config hash (for source-specific options). The `**` double splat lets subclasses accept extra keyword arguments without the base class needing to know about them.

The mapping logic lives in the base class because it is shared across all sources that deal with key-value rows:

```ruby
# lib/data_porter/sources/base.rb (private methods)
def apply_csv_mapping(row)
  mappings = @target_class._csv_mappings
  return auto_map(row) if mappings.nil? || mappings.empty?

  explicit_map(row, mappings)
end

def auto_map(row)
  row.to_h.transform_keys { |k| k.parameterize(separator: "_").to_sym }
end

def explicit_map(row, mappings)
  mappings.each_with_object({}) do |(header, column), hash|
    hash[column] = row[header]
  end
end
```

There are two mapping strategies. When a target defines `csv_mapping`, explicit mapping applies: only the declared header-to-column pairs are extracted, and anything else in the row is silently dropped. When no mapping is defined, auto-mapping kicks in: every header is parameterized into a snake_case symbol (`"First Name"` becomes `:first_name`). This lets simple imports work with zero configuration while giving complex imports full control over which columns matter.

### Step 3 -- The CSV source and source resolution

The CSV source implements `fetch` by parsing content through Ruby's standard library `CSV` class:

```ruby
# lib/data_porter/sources/csv.rb
class Csv < Base
  def initialize(data_import, content: nil)
    super(data_import)
    @content = content
  end

  def fetch
    rows = []
    ::CSV.parse(csv_content, **csv_options) do |row|
      rows << apply_csv_mapping(row)
    end
    rows
  end

  private

  def csv_content
    @content || download_file
  end

  def download_file
    @data_import.file.download
  end

  def csv_options
    { headers: true }.merge(extra_options)
  end

  def extra_options
    config = @data_import.config
    return {} unless config.is_a?(Hash)
    config.symbolize_keys.slice(:col_sep, :encoding)
  end
end
```

The `content:` keyword argument enables two usage modes. In production, `content` is nil and the source downloads the file from ActiveStorage via `@data_import.file.download`. In tests, you pass a CSV string directly, avoiding the need for file attachments or storage mocks. The `csv_options` method merges `headers: true` (so `CSV.parse` yields `CSV::Row` objects with named access) with any per-import overrides from the `config` column -- currently `col_sep` for semicolon-delimited files and `encoding` for non-UTF-8 data.

Source resolution ties it together:

```ruby
# lib/data_porter/sources.rb
module DataPorter
  module Sources
    REGISTRY = {
      csv: Csv
    }.freeze

    def self.resolve(type)
      REGISTRY.fetch(type.to_sym) { raise Error, "Unknown source type: #{type}" }
    end
  end
end
```

This is intentionally simpler than the Target Registry. Sources are engine-internal (the gem ships them), so a frozen hash with a `resolve` method is sufficient. When we add JSON and API sources in part 12, they get one line each in the registry.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| User association | Polymorphic `belongs_to :user` | A configurable foreign key or no association | Polymorphic works with any user model name without configuration; the engine does not need to know the host app's auth setup |
| State tracking | Integer-backed `enum` | A state machine gem (AASM, Statesman) | Six linear states do not need transition guards or history tracking yet; a gem would add a dependency for no immediate benefit |
| Auto-mapping fallback | `parameterize` + `to_sym` on headers | Requiring explicit mapping for all imports | Auto-mapping lets simple CSVs work with zero target configuration; explicit mapping is there when headers don't match column names |
| CSV content injection | `content:` keyword on initialize | Always reading from ActiveStorage | Injecting content makes tests fast and storage-independent; production code passes `nil` and falls through to `download_file` |
| Source-specific config | JSONB `config` column on DataImport | Separate columns for each option | A single JSONB column absorbs any source's options (col_sep, encoding, API headers) without schema changes |

## Testing it

DataImport specs verify validations, the status enum, and StoreModel integration:

```ruby
# spec/data_porter/data_import_spec.rb
it "validates source_type inclusion" do
  import = described_class.new(target_key: "guests", source_type: "xml")

  expect(import).not_to be_valid
  expect(import.errors[:source_type]).to include("is not included in the list")
end

it "saves and reloads with records" do
  import = described_class.create!(
    target_key: "guests", source_type: "csv",
    user_type: "User", user_id: 1
  )
  record = DataPorter::StoreModels::ImportRecord.new(line_number: 1, data: { name: "Alice" })
  import.update!(records: [record])

  reloaded = described_class.find(import.id)
  expect(reloaded.records.first.data).to eq({ "name" => "Alice" })
end
```

CSV source specs exercise both mapping modes and the config override:

```ruby
# spec/data_porter/sources/csv_spec.rb
it "parses CSV content and applies mapping" do
  csv_content = "Prenom,Nom,Email\nAlice,Smith,alice@example.com\n"
  source = described_class.new(data_import, content: csv_content)

  rows = source.fetch

  expect(rows.size).to eq(2)
  expect(rows.first).to eq(
    first_name: "Alice", last_name: "Smith", email: "alice@example.com"
  )
end

it "auto-maps when no csv_mapping defined" do
  csv_content = "First Name,Last Name\nAlice,Smith\n"
  source = described_class.new(import, content: csv_content)

  expect(source.fetch.first).to eq(first_name: "Alice", last_name: "Smith")
end
```

All source specs pass CSV strings directly through the `content:` parameter, so they run without ActiveStorage, without file fixtures, and without I/O.

## Recap

- The **DataImport model** is the database-backed record for every import, tracking target key, source type, status, parsed records (via StoreModel), and the initiating user (via polymorphic association).
- The **migration** uses JSONB columns for records, report, and config, keeping the schema stable as features evolve.
- The **Source base class** defines the `fetch` interface and shared column-mapping logic with two strategies: explicit mapping from the target's `csv_mapping` block, or automatic parameterize-based mapping when none is defined.
- The **CSV source** parses content via Ruby's `CSV` library, supports ActiveStorage file download in production and string injection in tests, and respects per-import config options like custom delimiters.

## Next up

We have targets that describe imports and sources that parse raw data into mapped hashes. But right now, nothing coordinates the flow: reading the file, building ImportRecord objects, running validations, transitioning the status, and persisting results. In part 7, we build the **Orchestrator** -- the class that ties `DataImport`, `Target`, and `Source` together into the complete parse-then-import workflow. That is where state transitions, per-record error handling, and ActiveJob integration come in.

---

*This is part 6 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Designing a Target DSL](#) | [Next: The Orchestrator](#)*
