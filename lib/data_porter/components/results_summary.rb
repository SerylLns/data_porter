# frozen_string_literal: true

module DataPorter
  module Components
    class ResultsSummary < Base
      def initialize(report:)
        super()
        @report = report
      end

      def view_template
        div(class: "dp-results") do
          p { "Created: #{@report.imported_count}" }
          p { "Errors: #{@report.errored_count}" }
        end
      end
    end
  end
end
