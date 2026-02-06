# frozen_string_literal: true

DataPorter.configure do |config|
  # Parent controller for the engine's controllers to inherit from.
  # This controls authentication, layouts, and helpers.
  # config.parent_controller = "ApplicationController"

  # ActiveJob queue name for import jobs.
  # config.queue_name = :imports

  # ActiveStorage service for uploaded files.
  # config.storage_service = :local

  # ActionCable channel prefix.
  # config.cable_channel_prefix = "data_porter"

  # Context builder: inject business data into targets.
  # Receives the current controller instance.
  # config.context_builder = ->(controller) {
  #   OpenStruct.new(
  #     user: controller.current_user
  #   )
  # }

  # Maximum number of records displayed in preview.
  # config.preview_limit = 500

  # Enabled source types.
  # config.enabled_sources = %i[csv json api]
end
