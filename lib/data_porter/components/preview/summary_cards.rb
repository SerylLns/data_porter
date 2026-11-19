# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class SummaryCards < Base
        STATUS_CARDS = [
          { css: "dp-card--complete", key: :complete_count, i18n: "ready" },
          { css: "dp-card--partial", key: :partial_count, i18n: "incomplete" },
          { css: "dp-card--missing", key: :missing_count, i18n: "missing" }
        ].freeze

        ACTION_CARDS = [
          { css: "dp-card--create", key: :create_count, i18n: "to_create" },
          { css: "dp-card--update", key: :update_count, i18n: "to_update" },
          { css: "dp-card--unchanged", key: :unchanged_count, i18n: "unchanged" },
          { css: "dp-card--excluded", key: :excluded_count, i18n: "excluded" }
        ].freeze

        def initialize(report:, editable: false, update_mode: false)
          super()
          @report = report
          @editable = editable
          @update_mode = update_mode
        end

        def view_template
          div(class: "dp-summary-cards") do
            cards.each { |card_def| card(card_def) }
          end
        end

        private

        def cards
          @update_mode ? STATUS_CARDS + ACTION_CARDS : STATUS_CARDS
        end

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

          { data: { "data-porter--inline-edit-target": "summary", count_key: key.to_s } }
        end
      end
    end
  end
end
