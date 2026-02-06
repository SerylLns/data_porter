# frozen_string_literal: true

require "store_model"
require_relative "error"

module DataPorter
  module StoreModels
    class Report
      include StoreModel::Model

      attribute :records_count, :integer, default: 0
      attribute :complete_count, :integer, default: 0
      attribute :partial_count, :integer, default: 0
      attribute :missing_count, :integer, default: 0
      attribute :duplicate_count, :integer, default: 0
      attribute :imported_count, :integer, default: 0
      attribute :errored_count, :integer, default: 0
      attribute :error_reports, Error.to_array_type, default: []
    end
  end
end
