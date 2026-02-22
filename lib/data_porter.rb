# frozen_string_literal: true

require "rails/engine"

module DataPorter
  class Error < StandardError; end
end

require_relative "data_porter/version"
require_relative "data_porter/configuration"
require_relative "data_porter/type_validator"
require_relative "data_porter/column_transformer"
require_relative "data_porter/store_models/error"
require_relative "data_porter/store_models/report"
require_relative "data_porter/store_models/import_record"
require_relative "data_porter/target"
require_relative "data_porter/registry"
require_relative "data_porter/sources"
require_relative "data_porter/record_validator"
require_relative "data_porter/record_revalidator"
require_relative "data_porter/broadcaster"
require_relative "data_porter/webhook_notifier"
require_relative "data_porter/orchestrator"
require_relative "data_porter/auto_mapper"
require_relative "data_porter/rejects_csv_builder"
require_relative "data_porter/components"
require_relative "data_porter/engine"

module DataPorter
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
