# frozen_string_literal: true

module DataPorter
  module Components
    module Progress
      class Bar < Base
        def initialize(import_id:)
          super()
          @import_id = import_id
        end

        def view_template
          div(class: "dp-progress", **stimulus_controller_attrs) do
            render_bar
          end
        end

        private

        def render_bar
          div(class: "dp-progress-bar", data_data_porter__progress_target: "bar", style: "width: 0%") do
            span(data_data_porter__progress_target: "text") { "0%" }
          end
        end

        def stimulus_controller_attrs
          {
            data_controller: "data-porter--progress",
            data_data_porter__progress_id_value: @import_id.to_s
          }
        end
      end
    end
  end
end
