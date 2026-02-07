# Targets

Targets are plain Ruby classes in `app/importers/` that inherit from `DataPorter::Target`. Each target defines one import type: its columns, sources, mappings, and persistence logic.

## Generator

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

## Class-level DSL

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
end
```

### `label(value)`

Human-readable name shown in the UI.

### `model_name(value)`

The ActiveRecord model name this target imports into (for display purposes).

### `icon(value)`

CSS icon class (e.g. FontAwesome) shown in the UI.

### `sources(*types)`

Accepted source types: `:csv`, `:json`, `:api`, `:xlsx`.

### `columns { ... }`

Defines the expected columns for this import. Each column accepts:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | Symbol | (required) | Column identifier |
| `type` | Symbol | `:string` | One of `:string`, `:integer`, `:decimal`, `:boolean`, `:date` |
| `required` | Boolean | `false` | Whether the column must have a value |
| `label` | String | Humanized name | Display label in the preview |

### `csv_mapping { ... }`

Maps CSV/XLSX header names to column names when they don't match:

```ruby
csv_mapping do
  map "First Name" => :first_name
  map "E-mail" => :email
end
```

### `json_root(path)`

Dot-separated path to the array of records within a JSON document:

```ruby
json_root "data.users"
```

Given `{ "data": { "users": [...] } }`, records are extracted from `data.users`.

### `api_config { ... }`

See [Sources: API](SOURCES.md#api) for full documentation.

### `deduplicate_by(*keys)`

Skip records that share the same value(s) for the given column(s):

```ruby
deduplicate_by :email
deduplicate_by :first_name, :last_name
```

### `dry_run_enabled`

Enables dry run mode for this target. A "Dry Run" button appears in the preview step. Dry run executes the full import pipeline (transform, validate, persist) inside a rolled-back transaction, giving a validation report without modifying the database.

## Instance Methods

Override these in your target to customize behavior.

### `transform(record)`

Transform a record before validation. Must return the (modified) record.

```ruby
def transform(record)
  record.attributes["email"] = record.attributes["email"]&.downcase
  record
end
```

### `validate(record)`

Add custom validation errors to a record:

```ruby
def validate(record)
  record.add_error("Email is invalid") unless record.attributes["email"]&.include?("@")
end
```

### `persist(record, context:)`

**Required.** Save the record to your database. Raises `NotImplementedError` if not overridden.

```ruby
def persist(record, context:)
  User.create!(record.attributes)
end
```

### `after_import(results, context:)`

Called once after all records have been processed:

```ruby
def after_import(results, context:)
  AdminMailer.import_complete(context.user, results).deliver_later
end
```

### `on_error(record, error, context:)`

Called when a record fails to import:

```ruby
def on_error(record, error, context:)
  Sentry.capture_exception(error, extra: { record: record.attributes })
end
```
