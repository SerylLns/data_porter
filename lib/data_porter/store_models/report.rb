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
      attribute :create_count, :integer, default: 0
      attribute :update_count, :integer, default: 0
      attribute :unchanged_count, :integer, default: 0
      attribute :excluded_count, :integer, default: 0
      attribute :imported_count, :integer, default: 0
      attribute :updated_count, :integer, default: 0
      attribute :skipped_count, :integer, default: 0
      attribute :errored_count, :integer, default: 0
      attribute :error_reports, Error.to_array_type, default: []

      PREVIEW_COUNTS = %i[
        complete_count partial_count missing_count create_count update_count unchanged_count excluded_count
      ].freeze

      def preview_counts
        PREVIEW_COUNTS.index_with { |key| public_send(key) }
      end
    end
  end
end
