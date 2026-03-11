# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class Table < Base
        def initialize(columns:, records:, editable: false, update_url: nil)
          super()
          @columns = columns
          @records = records
          @editable = editable
          @update_url = update_url
        end

        def view_template
          div(**wrapper_attrs) do
            table(class: "dp-table") do
              render_header
              render_body
            end
          end
        end

        private

        def wrapper_attrs
          attrs = { class: "dp-preview-table" }
          return attrs unless @editable

          attrs[:data] = {
            controller: "data-porter--inline-edit",
            "data-porter--inline-edit-update-url-value": @update_url
          }
          attrs
        end

        def render_header
          thead do
            tr do
              th { I18n.t("data_porter.components.table.line_number") }
              th { I18n.t("data_porter.components.table.status") }
              @columns.each { |col| th { col.label } }
              th { I18n.t("data_porter.components.table.errors") }
            end
          end
        end

        def render_body
          tbody do
            @records.each { |record| render_row(record) }
          end
        end

        def render_row(record)
          tr(**row_attrs(record)) do
            td { record.line_number.to_s }
            td { record.status }
            @columns.each { |col| render_cell(record, col) }
            render_errors_cell(record)
          end
        end

        def render_cell(record, col)
          value = cell_value(record, col)
          attrs = cell_attrs(record, col, value)
          attrs[:title] = value if value.length > 30
          td(**attrs) { value }
        end

        def render_errors_cell(record)
          td(**errors_cell_attrs(record)) { error_messages(record) }
        end

        def cell_value(record, col)
          (record.data[col.name.to_s] || record.data[col.name]).to_s
        end

        def row_attrs(record)
          attrs = { class: "dp-row--#{record.status}" }
          return attrs unless @editable

          attrs[:data] = { line_number: record.line_number }
          attrs
        end

        def cell_attrs(record, col, value)
          return {} unless @editable

          {
            class: "dp-cell--editable",
            data: {
              action: "click->data-porter--inline-edit#edit",
              "data-porter--inline-edit-target": "cell",
              value: value,
              line_number: record.line_number,
              column: col.name.to_s
            }
          }
        end

        def errors_cell_attrs(record)
          attrs = { class: "dp-errors" }
          return attrs unless @editable

          attrs[:data] = {
            "data-porter--inline-edit-target": "errors",
            line_number: record.line_number
          }
          attrs
        end

        def error_messages(record)
          record.errors_list.map(&:message).join(", ")
        end
      end
    end
  end
end
