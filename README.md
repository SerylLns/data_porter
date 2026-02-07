# DataPorter

A mountable Rails engine for 3-step data import workflows: **Upload**, **Preview**, **Import**.

Supports CSV, JSON, XLSX, and API sources with a declarative DSL for defining import targets. Business-agnostic by design -- all domain logic lives in your host app.

![Import list with status badges](docs/screenshots/index-with-previewing.jpg)

![New import modal with dropzone](docs/screenshots/modal-new-import.jpg)

![Preview with summary cards and data table](docs/screenshots/preview.jpg)

## Requirements

- Ruby >= 3.2
- Rails >= 7.0
- ActionCable (for real-time progress updates)
- ActiveStorage (for file uploads)

## Installation

Add the gem to your Gemfile:

```bash
bundle add data_porter
```

Run the install generator:

```bash
bin/rails generate data_porter:install
```

This will:
- Create the migration for `data_porter_imports`
- Add an initializer at `config/initializers/data_porter.rb`
- Create the `app/importers/` directory
- Mount the engine at `/imports`

Run the migration:

```bash
bin/rails db:migrate
```

## Quick Start

Generate a target:

```bash
bin/rails generate data_porter:target Product name:string:required price:integer sku:string
```

Implement the `persist` method in `app/importers/product_target.rb`:

```ruby
# frozen_string_literal: true

class ProductTarget < DataPorter::Target
  label "Product"
  model_name "Product"
  icon "fas fa-file-import"
  sources :csv

  columns do
    column :name,  type: :string,  required: true
    column :price, type: :integer
    column :sku,   type: :string
  end

  def persist(record, context:)
    Product.create!(record.attributes)
  end
end
```

Visit `/imports` and start importing.

## Configuration

All options are set in `config/initializers/data_porter.rb`:

```ruby
DataPorter.configure do |config|
  # Parent controller for the engine's controllers to inherit from.
  # Controls authentication, layouts, and helpers.
  config.parent_controller = "ApplicationController"

  # ActiveJob queue name for import jobs.
  config.queue_name = :imports

  # ActiveStorage service for uploaded files.
  config.storage_service = :local

  # ActionCable channel prefix.
  config.cable_channel_prefix = "data_porter"

  # Context builder: inject business data into targets.
  # Receives the current controller instance.
  config.context_builder = ->(controller) {
    OpenStruct.new(user: controller.current_user)
  }

  # Maximum number of records displayed in preview.
  config.preview_limit = 500

  # Enabled source types.
  config.enabled_sources = %i[csv json api xlsx]
end
```

| Option | Default | Description |
|---|---|---|
| `parent_controller` | `"ApplicationController"` | Controller class the engine inherits from |
| `queue_name` | `:imports` | ActiveJob queue for import jobs |
| `storage_service` | `:local` | ActiveStorage service name |
| `cable_channel_prefix` | `"data_porter"` | ActionCable stream prefix |
| `context_builder` | `nil` | Lambda receiving the controller, returns context passed to target methods |
| `preview_limit` | `500` | Max records shown in the preview step |
| `enabled_sources` | `%i[csv json api xlsx]` | Source types available in the UI |

## Defining Targets

Targets are plain Ruby classes in `app/importers/` that inherit from `DataPorter::Target`.

### Class-level DSL

```ruby
class OrderTarget < DataPorter::Target
  label "Orders"
  model_name "Order"
  icon "fas fa-shopping-cart"
  sources :csv, :json, :api, :xlsx

  columns do
    column :order_number, type: :string, required: true
    column :total,        type: :decimal
    column :placed_at,    type: :date
    column :active,       type: :boolean
    column :quantity,     type: :integer
  end

  csv_mapping do
    map "Order #" => :order_number
    map "Total ($)" => :total
  end

  json_root "data.orders"

  api_config do
    endpoint "https://api.example.com/orders"
    headers({ "Authorization" => "Bearer token" })
    response_root "data.orders"
  end

  deduplicate_by :order_number

  dry_run_enabled

  # ...
end
```

#### `label(value)`

Human-readable name shown in the UI.

#### `model_name(value)`

The ActiveRecord model name this target imports into (for display purposes).

#### `icon(value)`

CSS icon class (e.g. FontAwesome) shown in the UI.

#### `sources(*types)`

Accepted source types: `:csv`, `:json`, `:api`, `:xlsx`.

#### `columns { ... }`

Defines the expected columns for this import. Each column accepts:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | Symbol | (required) | Column identifier |
| `type` | Symbol | `:string` | One of `:string`, `:integer`, `:decimal`, `:boolean`, `:date` |
| `required` | Boolean | `false` | Whether the column must have a value |
| `label` | String | Humanized name | Display label in the preview |

#### `csv_mapping { ... }`

Maps CSV header names to column names when they don't match:

```ruby
csv_mapping do
  map "First Name" => :first_name
  map "E-mail" => :email
end
```

#### `json_root(path)`

Dot-separated path to the array of records within a JSON document:

```ruby
json_root "data.users"
```

Given `{ "data": { "users": [...] } }`, records are extracted from `data.users`.

#### `api_config { ... }`

Configures the API source:

```ruby
api_config do
  endpoint "https://api.example.com/records"
  headers({ "Authorization" => "Bearer token", "Accept" => "application/json" })
  response_root "data.items"
end
```

#### `deduplicate_by(*keys)`

Skip records that share the same value(s) for the given column(s):

```ruby
deduplicate_by :email
deduplicate_by :first_name, :last_name
```

#### `dry_run_enabled`

Enables dry run mode for this target (see [Dry Run](#dry-run)).

### Instance Methods

Override these in your target to customize behavior:

#### `transform(record)`

Transform a record before validation. Must return the (modified) record.

```ruby
def transform(record)
  record.attributes["email"] = record.attributes["email"]&.downcase
  record
end
```

#### `validate(record)`

Add custom validation errors to a record:

```ruby
def validate(record)
  record.add_error("Email is invalid") unless record.attributes["email"]&.include?("@")
end
```

#### `persist(record, context:)`

**Required.** Save the record to your database. Raises `NotImplementedError` if not overridden.

```ruby
def persist(record, context:)
  User.create!(record.attributes)
end
```

#### `after_import(results, context:)`

Called once after all records have been processed:

```ruby
def after_import(results, context:)
  AdminMailer.import_complete(context.user, results).deliver_later
end
```

#### `on_error(record, error, context:)`

Called when a record fails to import:

```ruby
def on_error(record, error, context:)
  Sentry.capture_exception(error, extra: { record: record.attributes })
end
```

## Source Types

### CSV

Upload a CSV file. Configure header mappings with `csv_mapping` when headers don't match your column names.

### XLSX

Upload an Excel `.xlsx` file. Uses the same `csv_mapping` for header-to-column mapping. By default the first sheet is parsed; select a different sheet via config:

```ruby
import.config = { "sheet_index" => 1 }
```

Powered by [creek](https://github.com/pythonicrubyist/creek) for streaming, memory-efficient parsing.

### JSON

Upload a JSON file. Use `json_root` to specify the path to the records array. Raw JSON arrays are supported without `json_root`.

### API

Fetch records from an external API endpoint. No file upload is needed -- the engine calls the API directly.

#### Basic usage

```ruby
api_config do
  endpoint "https://api.example.com/data"
  headers({ "Authorization" => "Bearer token" })
  response_root "results"
end
```

| Option | Type | Description |
|---|---|---|
| `endpoint` | String or Proc | URL to fetch records from |
| `headers` | Hash or Proc | HTTP headers sent with the request |
| `response_root` | String | Key in the JSON response containing the records array (omit for top-level arrays) |

#### Dynamic endpoints and headers

Both `endpoint` and `headers` accept lambdas for runtime values. The endpoint lambda receives the import's `config` hash (populated from the form):

```ruby
api_config do
  endpoint ->(params) { "https://api.example.com/events?page=#{params[:page]}" }
  headers -> { { "Authorization" => "Bearer #{ENV['API_TOKEN']}" } }
  response_root "data"
end
```

#### Example: importing from a paginated API

```ruby
class EventTarget < DataPorter::Target
  label "Events"
  model_name "Event"
  sources :api

  api_config do
    endpoint "https://api.example.com/events"
    headers -> { { "Authorization" => "Bearer #{ENV['EVENTS_API_KEY']}", "Accept" => "application/json" } }
    response_root "events"
  end

  columns do
    column :name,       type: :string, required: true
    column :date,       type: :date
    column :venue,      type: :string
    column :capacity,   type: :integer
  end

  def persist(record, context:)
    Event.create!(record.attributes)
  end
end
```

When a user creates an import with source type **API**, the engine skips file upload entirely, calls the configured endpoint, parses the JSON response, and feeds the records through the same preview/validate/import pipeline as CSV and JSON sources.

## Import Workflow

Each import progresses through these statuses:

```
pending -> parsing -> previewing -> importing -> completed
                                             \-> failed
         pending -> parsing -> dry_running -> previewing
```

| Status | Description |
|---|---|
| `pending` | Import created, waiting for file/source |
| `parsing` | Source is being read and records extracted |
| `previewing` | Records parsed and ready for review |
| `importing` | Records are being persisted |
| `completed` | All records processed |
| `failed` | Import encountered a fatal error |
| `dry_running` | Dry run validation in progress |

### Routes

The engine provides these routes (mounted at your chosen path):

| Method | Path | Action |
|---|---|---|
| GET | `/imports` | List imports |
| GET | `/imports/new` | New import form |
| POST | `/imports` | Create import |
| GET | `/imports/:id` | Show import |
| POST | `/imports/:id/parse` | Parse uploaded source |
| POST | `/imports/:id/confirm` | Confirm and run import |
| POST | `/imports/:id/cancel` | Cancel import |
| POST | `/imports/:id/dry_run` | Run dry validation |

## Dry Run

When `dry_run_enabled` is declared on a target, a "Dry Run" button appears in the preview step. Dry run executes the full import pipeline (transform, validate, persist) inside a rolled-back transaction, giving you a validation report without modifying the database.

## Real-time Updates

DataPorter broadcasts import progress via ActionCable. The channel streams on:

```
#{cable_channel_prefix}/imports/#{import_id}
```

The default prefix is `data_porter`, so a typical stream name is `data_porter/imports/42`.

The engine ships with a Stimulus controller that automatically subscribes to the channel and updates the UI during parsing and importing.

## Generators

### `data_porter:install`

```bash
bin/rails generate data_porter:install
```

Sets up the migration, initializer, `app/importers/` directory, and mounts the engine.

### `data_porter:target`

```bash
bin/rails generate data_porter:target ModelName column:type[:required] ...
```

Examples:

```bash
bin/rails generate data_porter:target User email:string:required name:string age:integer
bin/rails generate data_porter:target Product name:string price:decimal
```

Column format: `name:type[:required]`

Supported types: `string`, `integer`, `decimal`, `boolean`, `date`.

## Development

```bash
git clone https://github.com/SerylLns/data_porter.git
cd data_porter
bin/setup
```

Run the test suite:

```bash
bundle exec rspec
```

Run the linter:

```bash
bundle exec rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
