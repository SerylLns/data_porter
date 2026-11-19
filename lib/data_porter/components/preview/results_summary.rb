# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class ResultsSummary < Base
        def initialize(report:, duration: nil, update_mode: false)
          super()
          @report = report
          @duration = duration
          @update_mode = update_mode
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
          key = success? ? "completed" : "completed_with_errors"
          h3(class: "dp-results__title") { I18n.t("data_porter.components.results_summary.#{key}") }
        end

        def render_stats
          div(class: "dp-results__cards") do
            stat("dp-results__stat--success", @report.imported_count, label(@update_mode ? "created" : "imported"))
            render_update_stats if @update_mode
            stat("dp-results__stat--error", @report.errored_count, label("errors"))
            stat("dp-results__stat--warning", skipped_count, label("skipped")) if skipped_count.positive?
          end
        end

        def render_update_stats
          stat("dp-results__stat--updated", @report.updated_count, label("updated"))
          stat("dp-results__stat--untouched", @report.skipped_count, label("untouched"))
        end

        def label(key)
          I18n.t("data_porter.components.results_summary.#{key}")
        end

        def render_duration
          div(class: "dp-results__duration") do
            I18n.t("data_porter.components.results_summary.duration", duration: @duration)
          end
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
          @report.errored_count.zero? && skipped_count.zero?
        end

        def skipped_count
          @report.missing_count.to_i + @report.partial_count.to_i
        end
      end
    end
  end
end
