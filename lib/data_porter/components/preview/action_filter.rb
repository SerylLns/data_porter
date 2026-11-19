# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class ActionFilter < Base
        FILTERS = [
          { value: nil, i18n: "all" },
          { value: "create", i18n: "to_create" },
          { value: "update", i18n: "to_update" },
          { value: "unchanged", i18n: "unchanged" },
          { value: "excluded", i18n: "excluded" }
        ].freeze

        def initialize(current:, base_url:)
          super()
          @current = current
          @base_url = base_url
        end

        def view_template
          nav(class: "dp-filters") do
            FILTERS.each { |filter| render_filter(filter) }
          end
        end

        private

        def render_filter(filter)
          active = filter[:value] == @current
          a(href: filter_url(filter[:value]), class: ["dp-filter", ("dp-filter--active" if active)].compact.join(" "),
            aria_current: ("page" if active)) do
            I18n.t("data_porter.components.action_filter.#{filter[:i18n]}")
          end
        end

        def filter_url(value)
          query = value ? "?#{{ filter: value }.to_query}" : ""
          "#{@base_url}#{query}#records"
        end
      end
    end
  end
end
