# Configuration

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

  # Auto-purge completed/failed imports older than this duration.
  # Set to nil to disable. Run `rake data_porter:purge` manually or via cron.
  config.purge_after = 60.days
end
```

## Options reference

| Option | Default | Description |
|---|---|---|
| `parent_controller` | `"ApplicationController"` | Controller class the engine inherits from |
| `queue_name` | `:imports` | ActiveJob queue for import jobs |
| `storage_service` | `:local` | ActiveStorage service name |
| `cable_channel_prefix` | `"data_porter"` | ActionCable stream prefix |
| `context_builder` | `nil` | Lambda receiving the controller, returns context passed to target methods |
| `preview_limit` | `500` | Max records shown in the preview step |
| `enabled_sources` | `%i[csv json api xlsx]` | Source types available in the UI |
| `purge_after` | `60.days` | Auto-purge completed/failed imports older than this duration |

## Authentication

The engine inherits authentication from `parent_controller`. Set it to your authenticated base controller:

```ruby
config.parent_controller = "Admin::BaseController"
```

All engine routes will require the same authentication as your base controller.

## Context builder

The `context_builder` lambda lets you inject business data (current user, tenant, permissions) into target methods (`persist`, `after_import`, `on_error`):

```ruby
config.context_builder = ->(controller) {
  OpenStruct.new(
    user: controller.current_user,
    organization: controller.current_organization
  )
}
```

The returned object is available as `context` in all target instance methods.

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
