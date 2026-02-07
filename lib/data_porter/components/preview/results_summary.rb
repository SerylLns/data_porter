# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class ResultsSummary < Base
        def initialize(report:, duration: nil)
          super()
          @report = report
          @duration = duration
        end

        def view_template
          div(class: "dp-results #{result_class}") do
            render_icon
            render_title
            render_stats
            render_duration if @duration
          end
        end

        private

        def render_icon
          div(class: "dp-results__icon") { success? ? "\u2714" : "\u26A0" }
        end

        def render_title
          h3(class: "dp-results__title") { success? ? "Import completed" : "Import completed with errors" }
        end

        def render_stats
          div(class: "dp-results__cards") do
            stat("dp-results__stat--success", @report.imported_count, "Imported")
            stat("dp-results__stat--error", @report.errored_count, "Errors")
          end
        end

        def render_duration
          div(class: "dp-results__duration") { "Duration: #{@duration}" }
        end

        def stat(css_class, count, label)
          div(class: "dp-results__stat #{css_class}") do
            strong { count.to_s }
            span { label }
          end
        end

        def result_class
          success? ? "dp-results--success" : "dp-results--partial"
        end

        def success?
          @report.errored_count.zero?
        end
      end
    end
  end
end
