# frozen_string_literal: true

module DataPorter
  module Components
    class FailureAlert < Base
      def initialize(report:)
        super()
        @report = report
      end

      def view_template
        div(class: "dp-alert dp-alert--danger") do
          @report.error_reports.each do |err|
            p { err.message }
          end
        end
      end
    end
  end
end
