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
          if @page > 1
            a(href: page_url(@page - 1), class: "dp-pagination__btn") { "\u2190 Previous" }
          else
            span(class: "dp-pagination__btn dp-pagination__btn--disabled") { "\u2190 Previous" }
          end
        end

        def render_indicator
          span(class: "dp-pagination__info") { "Page #{@page} of #{@total_pages}" }
        end

        def render_next
          if @page < @total_pages
            a(href: page_url(@page + 1), class: "dp-pagination__btn") { "Next \u2192" }
          else
            span(class: "dp-pagination__btn dp-pagination__btn--disabled") { "Next \u2192" }
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
