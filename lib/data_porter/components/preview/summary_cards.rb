# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class SummaryCards < Base
        def initialize(report:)
          super()
          @report = report
        end

        def view_template
          div(class: "dp-summary-cards") do
            card("dp-card--complete", @report.complete_count, "Ready")
            card("dp-card--partial", @report.partial_count, "Incomplete")
            card("dp-card--missing", @report.missing_count, "Missing")
            card("dp-card--duplicate", @report.duplicate_count, "Duplicates")
          end
        end

        private

        def card(css_class, count, label)
          div(class: "dp-card #{css_class}") do
            strong { count.to_s }
            plain " #{label}"
          end
        end
      end
    end
  end
end
