# frozen_string_literal: true

module DataPorter
  module Components
    module Mapping
      class ColumnRow < Base
        def initialize(file_header:, target_fields:, selected: nil)
          super()
          @file_header = file_header
          @target_fields = target_fields
          @selected = selected
        end

        def view_template
          div(class: "dp-mapping-row") do
            render_header
            render_arrow
            render_select
          end
        end

        private

        def render_header
          span(class: "dp-mapping-row__header") { @file_header }
        end

        def render_arrow
          span(class: "dp-mapping-row__arrow") { "→" }
        end

        def render_select
          select(
            name: "column_mapping[#{@file_header}]",
            class: "dp-select dp-mapping-row__select",
            data_data_porter__mapping_target: "columnSelect"
          ) do
            option(value: "") { "Skip this column" }
            @target_fields.each { |label, value| render_field_option(label, value) }
          end
        end

        def render_field_option(label, value)
          option(value: value, selected: value == @selected) { label }
        end
      end
    end
  end
end
