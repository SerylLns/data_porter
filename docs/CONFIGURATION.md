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

## Real-time updates

DataPorter broadcasts import progress via ActionCable. The channel streams on:

```
#{cable_channel_prefix}/imports/#{import_id}
```

The default prefix is `data_porter`, so a typical stream name is `data_porter/imports/42`.

The engine ships with a Stimulus controller that automatically subscribes to the channel and updates a progress bar during parsing and importing. If ActionCable is unavailable, it falls back to polling every 3 seconds.
