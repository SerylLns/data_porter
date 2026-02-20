# frozen_string_literal: true

module DataPorter
  module Components
    module Shared
      class Pagination < Base
        def initialize(page:, total_pages:, base_url:)
          super()
          @page = page
          @total_pages = total_pages
          @base_url = base_url
        end

        def view_template
          return if @total_pages <= 1

          nav(class: "dp-pagination") do
            render_prev
            render_indicator
            render_next
          end
        end

        private

        def render_prev
          label = "\u2190 #{I18n.t("data_porter.components.pagination.previous")}"
          if @page > 1
            a(href: page_url(@page - 1), class: "dp-pagination__btn") { label }
          else
            span(class: "dp-pagination__btn dp-pagination__btn--disabled") { label }
          end
        end

        def render_indicator
          span(class: "dp-pagination__info") do
            I18n.t("data_porter.components.pagination.page_info", page: @page, total: @total_pages)
          end
        end

        def render_next
          label = "#{I18n.t("data_porter.components.pagination.next")} \u2192"
          if @page < @total_pages
            a(href: page_url(@page + 1), class: "dp-pagination__btn") { label }
          else
            span(class: "dp-pagination__btn dp-pagination__btn--disabled") { label }
          end
        end

        def page_url(number)
          separator = @base_url.include?("?") ? "&" : "?"
          "#{@base_url}#{separator}page=#{number}#records"
        end
      end
    end
  end
end
