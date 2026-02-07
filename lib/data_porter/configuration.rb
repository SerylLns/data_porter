# frozen_string_literal: true

module DataPorter
  class Configuration
    attr_accessor :parent_controller,
                  :queue_name,
                  :storage_service,
                  :cable_channel_prefix,
                  :context_builder,
                  :preview_limit,
                  :enabled_sources,
                  :scope,
                  :purge_after,
                  :max_file_size

    def initialize
      @parent_controller = "ApplicationController"
      @queue_name = :imports
      @storage_service = :local
      @cable_channel_prefix = "data_porter"
      @context_builder = nil
      @preview_limit = 500
      @enabled_sources = %i[csv json api xlsx]
      @scope = nil
      @purge_after = 60.days
      @max_file_size = 10.megabytes
    end
  end
end
