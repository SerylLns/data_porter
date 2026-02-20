---
title: Configuration
icon: material/cog
---

# Configuration

All options are set in `config/initializers/data_porter.rb`:

```ruby
DataPorter.configure do |config|
  # Parent controller for the engine's controllers to inherit from.
  # Defaults to ActionController::Base (no authentication).
  # Set to "ApplicationController" to inherit authentication, layouts, and helpers.
  config.parent_controller = "ApplicationController"

  # ActiveJob queue name for import jobs.
  config.queue_name = :imports

  # ActiveStorage service for uploaded files.
  config.storage_service = :local

  # ActionCable channel prefix.
  config.cable_channel_prefix = "data_porter"

  # Context builder: inject business data into targets.
  # Receives the DataImport record.
  config.context_builder = ->(data_import) {
    { user: data_import.user }
  }

  # Maximum number of records displayed in preview.
  config.preview_limit = 500

  # Enabled source types.
  config.enabled_sources = %i[csv json api xlsx]

  # Scope imports per owner (multi-tenant isolation).
  # The lambda receives current_user and returns the owner object.
  # Requires current_user in the parent controller.
  config.scope = ->(user) { user }

  # Auto-purge completed/failed imports older than this duration.
  # Set to nil to disable. Run `rake data_porter:purge` manually or via cron.
  config.purge_after = 60.days

  # Maximum file size for uploads (default: 10 MB).
  config.max_file_size = 10.megabytes

  # Maximum number of records per import (default: 10,000).
  # Set to nil to disable.
  config.max_records = 10_000

  # Transaction mode for imports.
  # :per_record -- each record persisted independently (default)
  # :all -- single transaction, rolls back entirely on any failure
  config.transaction_mode = :per_record
end
```

## Options reference

| Option | Default | Description |
|---|---|---|
| `parent_controller` | `"ActionController::Base"` | Controller class the engine inherits from |
| `queue_name` | `:imports` | ActiveJob queue for import jobs |
| `storage_service` | `:local` | ActiveStorage service name |
| `cable_channel_prefix` | `"data_porter"` | ActionCable stream prefix |
| `context_builder` | `nil` | Lambda receiving the DataImport record, returns context passed to target methods |
| `preview_limit` | `500` | Max records shown in the preview step |
| `enabled_sources` | `%i[csv json api xlsx]` | Source types available in the UI |
| `scope` | `nil` | Lambda receiving `current_user`, returns the owner object for import isolation |
| `purge_after` | `60.days` | Auto-purge completed/failed imports older than this duration |
| `max_file_size` | `10.megabytes` | Maximum file size for uploads |
| `max_records` | `10_000` | Maximum number of records per import (nil to disable) |
| `transaction_mode` | `:per_record` | `:per_record` or `:all` (single transaction rollback) |

## Authentication

By default, the engine inherits from `ActionController::Base` -- no authentication is required. This avoids conflicts with authorization gems (Pundit, CanCanCan, Action Policy, etc.) that add verification callbacks on `ApplicationController`.

To add authentication, set `parent_controller` to your authenticated base controller:

```ruby
config.parent_controller = "ApplicationController"
# or a dedicated controller:
config.parent_controller = "Admin::BaseController"
```

All engine routes will then require the same authentication as your base controller.

> **Note:** If your parent controller uses an authorization gem that enforces `after_action` verification (e.g. Pundit's `verify_policy_scoped`), you'll need to skip those callbacks for the engine's controllers. The simplest approach is to exclude `data_porter/` in your skip condition.

## Context builder

The `context_builder` lambda lets you inject business data (current user, tenant, permissions) into target methods (`persist`, `after_import`, `on_error`). It receives the `DataImport` record:

```ruby
config.context_builder = ->(data_import) {
  { user: data_import.user, import_id: data_import.id }
}
```

The returned object is available as `context` in all target instance methods.

## Scoped imports

The `scope` option enables multi-tenant isolation. Each user only sees their own imports, and cannot access other users' imports by URL (IDOR protection).

The lambda receives `current_user` and returns the **owner** of the import. The owner is stored in the polymorphic `user` association, so it can be any ActiveRecord model:

```ruby
# Scope by user (each user sees their own imports)
config.scope = ->(user) { user }

# Scope by hotel (all users of the same hotel share imports)
config.scope = ->(user) { user.hotel }

# Scope by organization
config.scope = ->(member) { member.organization }
```

The same `scope` lambda is used for both **storing** (on create) and **filtering** (on index/show), so there's no risk of mismatch.

Requirements:
- `parent_controller` must expose `current_user` (can be any model: User, Member, Admin...)
- The `data_porter_imports` table has polymorphic `user_id` / `user_type` columns (created by the install migration)

When `scope` is `nil` (default), imports are associated with `current_user` directly (if available). When `current_user` is not available, all imports are visible.

## Real-time progress

DataPorter tracks import progress via JSON polling. The Stimulus progress controller polls `GET /imports/:id/status` every second and updates an animated progress bar.

The status endpoint returns:

```json
{
  "status": "importing",
  "progress": { "current": 42, "total": 100, "percentage": 42 }
}
```

No ActionCable or WebSocket configuration required -- it works out of the box with any deployment.

## Auto-purge

Old completed/failed imports can be cleaned up automatically:

```bash
# Run manually
bin/rails data_porter:purge

# Or schedule via cron (e.g. with whenever or solid_queue)
# Removes imports older than purge_after (default: 60 days)
```

Attached files are purged from ActiveStorage along with the import record.

## i18n

All UI strings, error messages, and status labels are translatable via Rails I18n. The engine ships with English and French locales.

### Changing the language

Set your app's default locale in `config/application.rb`:

```ruby
config.i18n.default_locale = :fr
```

### Customizing labels

Override any key in your own locale file:

```yaml
# config/locales/data_porter.en.yml
en:
  data_porter:
    imports:
      confirm_import: "Run Import"
      delete_confirm: "Are you sure?"
```

Rails merges your keys over the gem's defaults -- no need to copy the entire file.

### Adding a new language

Use the locale generator to get a file with all keys pre-filled:

```bash
bin/rails generate data_porter:locale de
```

This creates `config/locales/data_porter.de.yml` with English values. Translate them and you're done.
