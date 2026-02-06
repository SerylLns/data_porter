# frozen_string_literal: true

require "rails/engine"
require_relative "data_porter/version"
require_relative "data_porter/configuration"
require_relative "data_porter/store_models/error"
require_relative "data_porter/store_models/report"
require_relative "data_porter/store_models/import_record"
require_relative "data_porter/engine"

module DataPorter
  class Error < StandardError; end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
