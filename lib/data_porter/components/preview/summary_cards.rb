# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class SummaryCards < Base
        CARDS = [
          { css: "dp-card--complete", key: :complete_count, i18n: "ready" },
          { css: "dp-card--partial", key: :partial_count, i18n: "incomplete" },
          { css: "dp-card--missing", key: :missing_count, i18n: "missing" },
          { css: "dp-card--duplicate", key: :duplicate_count, i18n: "duplicates" }
        ].freeze

        def initialize(report:, editable: false)
          super()
          @report = report
          @editable = editable
        end

        def view_template
          div(class: "dp-summary-cards") do
            CARDS.each { |card_def| card(card_def) }
          end
        end

        private

        def card(card_def)
          count = @report.send(card_def[:key])
          label = I18n.t("data_porter.components.summary_cards.#{card_def[:i18n]}")

          div(class: "dp-card #{card_def[:css]}") do
            strong(**count_attrs(card_def[:key])) { count.to_s }
            plain " #{label}"
          end
        end

        def count_attrs(key)
          return {} unless @editable

          { data: { "data-porter--inline-edit-target": "summary", count_key: key } }
        end
      end
    end
  end
end
