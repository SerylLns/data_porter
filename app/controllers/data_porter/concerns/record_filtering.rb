# frozen_string_literal: true

module DataPorter
  module Concerns
    module RecordFiltering
      extend ActiveSupport::Concern

      FILTERS = %w[create update unchanged excluded].freeze

      private

      def filter_records
        @filter = params[:filter] if @target._match_keys && FILTERS.include?(params[:filter])
        return unless @filter

        @records = @records.select { |record| matches_filter?(record) }
      end

      def matches_filter?(record)
        @filter == "excluded" ? record.excluded : record.action == @filter
      end
    end
  end
end
