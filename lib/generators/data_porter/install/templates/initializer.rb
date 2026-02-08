# frozen_string_literal: true

DataPorter.configure do |config|
  # Parent controller for the engine's controllers to inherit from.
  # This controls authentication, layouts, and helpers.
  # config.parent_controller = "ApplicationController"

  # ActiveJob queue name for import jobs.
  # config.queue_name = :default

  # ActiveStorage service for uploaded files.
  # config.storage_service = :local

  # ActionCable channel prefix.
  # config.cable_channel_prefix = "data_porter"

  # Context builder: inject business data into targets.
  # Receives the DataImport record.
  # config.context_builder = ->(data_import) {
  #   { user: data_import.user }
  # }

  # Maximum number of records displayed in preview.
  # config.preview_limit = 500

  # Enabled source types.
  # config.enabled_sources = %i[csv json xlsx api]

  # Scope imports per owner (multi-tenant isolation).
  # The lambda receives current_user and returns the owner object.
  # Works with any model: User, Member, Hotel, Organization...
  # config.scope = ->(user) { user }
  # config.scope = ->(user) { user.hotel }

  # Auto-purge completed/failed imports older than this duration.
  # Set to nil to disable auto-purge. Run `rake data_porter:purge` manually or via cron.
  # config.purge_after = 60.days
end
