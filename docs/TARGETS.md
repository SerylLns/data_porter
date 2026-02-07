# Targets

Targets are plain Ruby classes in `app/importers/` that inherit from `DataPorter::Target`. Each target defines one import type: its columns, sources, mappings, and persistence logic.

## Generator

```bash
bin/rails generate data_porter:target ModelName column:type[:required] ... [--sources csv xlsx]
```

Examples:

```bash
bin/rails generate data_porter:target User email:string:required name:string age:integer --sources csv xlsx
bin/rails generate data_porter:target Product name:string price:decimal --sources csv
bin/rails generate data_porter:target Order order_number:string total:decimal
```

Column format: `name:type[:required]`

Supported types: `string`, `integer`, `decimal`, `boolean`, `date`.

The `--sources` option specifies which source types the target accepts (default: `csv`). The UI will only show these sources when the target is selected.

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

  params do
    param :warehouse_id, type: :select, label: "Warehouse", required: true,
          collection: -> { Warehouse.pluck(:name, :id) }
    param :currency, type: :text, default: "USD"
  end
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

### `params { ... }`

Declares extra form fields shown when this target is selected in the import form. Values are stored in `config["import_params"]` and accessible via `import_params` in all instance methods.

```ruby
params do
  param :hotel_id, type: :select, label: "Hotel", required: true,
        collection: -> { Hotel.pluck(:name, :id) }
  param :currency, type: :text, label: "Currency", default: "EUR"
  param :batch_size, type: :number, label: "Batch Size", default: "100"
  param :tenant_id, type: :hidden, default: "abc123"
end
```

Each param accepts:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | Symbol | (required) | Param identifier |
| `type` | Symbol | `:text` | One of `:select`, `:text`, `:number`, `:hidden` |
| `required` | Boolean | `false` | Validated on import creation, shown with `*` in the form |
| `label` | String | Humanized name | Display label in the form |
| `default` | String | `nil` | Pre-filled value in the form |
| `collection` | Lambda or Array | `nil` | For `:select` type -- `[[label, value], ...]` |

Collection accepts both a lambda and a plain array. Use a lambda for dynamic data (evaluated when the form loads, not at boot time):

```ruby
param :hotel_id, type: :select, collection: -> { Hotel.pluck(:name, :id) }
param :status,   type: :select, collection: [%w[Active active], %w[Archived archived]]
```

## Instance Methods

### `import_params`

Returns a hash of the import params values set by the user in the form. Available in all instance methods (`persist`, `transform`, `validate`, `after_import`, `on_error`). Defaults to `{}` when no params are declared.

```ruby
def persist(record, context:)
  Guest.create!(
    record.attributes.merge(
      hotel_id: import_params["hotel_id"],
      currency: import_params["currency"]
    )
  )
end
```

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

## Full example

A complete target using most DSL features: multiple sources, import params, JSON root, API config, transform, custom validation, and lifecycle hooks.

```ruby
# frozen_string_literal: true

class ContactTarget < DataPorter::Target
  label "Contacts"
  model_name "Contact"
  icon "fas fa-address-book"
  sources :csv, :xlsx, :json, :api
  dry_run_enabled

  columns do
    column :name, type: :string, required: true
    column :email, type: :email
    column :phone_number, type: :string
    column :address, type: :string
    column :room, type: :string
  end

  params do
    param :default_room, type: :text, label: "Default room"
    param :import_source, type: :select, label: "Import source",
          collection: [%w[Manual manual], %w[Migration migration], ["Directory sync", "sync"]]
  end

  json_root "contacts"

  api_config do
    endpoint "http://localhost:3001/contacts"
    headers({ "Authorization" => "Bearer token" })
    response_root :contacts
  end

  def transform(record)
    apply_default_room(record)
    normalize_phone(record)
    record
  end

  def validate(record)
    validate_email_format(record)
  end

  def persist(record, context:)
    Contact.create!(record.attributes)
  end

  def after_import(results, context:)
    Rails.logger.info("[DataPorter] Contacts: #{results[:created]} created, #{results[:errored]} errors")
  end

  def on_error(record, error, context:)
    Rails.logger.warn("[DataPorter] Line #{record.line_number}: #{error.message}")
  end

  private

  def apply_default_room(record)
    return if record.data["room"].present?
    return unless import_params["default_room"].present?

    record.data["room"] = import_params["default_room"]
  end

  def normalize_phone(record)
    phone = record.data["phone_number"]
    return if phone.blank?

    record.data["phone_number"] = phone.gsub(/\s/, "")
  end

  def validate_email_format(record)
    email = record.data["email"]
    return if email.blank?
    return if email.match?(/\A[^@\s]+@[^@\s]+\z/)

    record.add_error("Invalid email format: #{email}")
  end
end
```

This target exercises:

| Feature | DSL / Hook | Effect |
|---|---|---|
| 4 sources | `sources :csv, :xlsx, :json, :api` | All source types available |
| Typed columns | `type: :string, :email` | Built-in validation |
| Required field | `required: true` on `name` | Rows without name get "missing" status |
| Dry run | `dry_run_enabled` | Dry run button in preview |
| Import params | `param :default_room`, `param :import_source` | Dynamic form fields |
| JSON root | `json_root "contacts"` | Extracts from `{"contacts": [...]}` |
| API config | `endpoint`, `headers`, `response_root` | Authenticated API fetch |
| Transform | `apply_default_room`, `normalize_phone` | Fill blanks, strip whitespace |
| Validate | `validate_email_format` | Custom error on invalid email |
| After import | Logs summary | Post-import hook |
| On error | Logs failed line | Per-record error hook |
