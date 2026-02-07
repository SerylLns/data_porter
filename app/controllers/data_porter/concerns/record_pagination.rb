# frozen_string_literal: true

module DataPorter
  module Concerns
    module RecordPagination
      extend ActiveSupport::Concern

      private

      def paginate_records
        per_page = 50
        @total_pages = (@records.size.to_f / per_page).ceil
        @total_pages = 1 if @total_pages.zero?
        @page = (params[:page] || 1).to_i.clamp(1, @total_pages)
        @records = @records.slice((@page - 1) * per_page, per_page) || []
      end
    end
  end
end
