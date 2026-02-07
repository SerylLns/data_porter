# frozen_string_literal: true

module DataPorter
  module Components
    module Progress
      class Bar < Base
        def initialize(import_id:, status_url: nil)
          super()
          @import_id = import_id
          @status_url = status_url
        end

        def view_template
          div(class: "dp-progress-container", **stimulus_attrs) do
            render_label
            render_bar
          end
        end

        private

        def render_label
          div(class: "dp-progress-label") do
            span(data_data_porter__progress_target: "label") { "Waiting..." }
          end
        end

        def render_bar
          div(class: "dp-progress") do
            div(class: "dp-progress-bar", data_data_porter__progress_target: "bar", style: "width: 0%") do
              span(data_data_porter__progress_target: "text") { "0%" }
            end
          end
        end

        def stimulus_attrs
          attrs = {
            data_controller: "data-porter--progress",
            data_data_porter__progress_id_value: @import_id.to_s
          }
          attrs[:data_data_porter__progress_url_value] = @status_url if @status_url
          attrs
        end
      end
    end
  end
end
