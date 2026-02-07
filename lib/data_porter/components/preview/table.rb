# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class Table < Base
        def initialize(columns:, records:)
          super()
          @columns = columns
          @records = records
        end

        def view_template
          div(class: "dp-preview-table") do
            table(class: "dp-table") do
              render_header
              render_body
            end
          end
        end

        private

        def render_header
          thead do
            tr do
              th { "#" }
              th { "Status" }
              @columns.each { |col| th { col.label } }
              th { "Errors" }
            end
          end
        end

        def render_body
          tbody do
            @records.each { |record| render_row(record) }
          end
        end

        def render_row(record)
          tr(class: "dp-row--#{record.status}") do
            td { record.line_number.to_s }
            td { record.status }
            @columns.each { |col| td { record.data[col.name.to_s].to_s } }
            td(class: "dp-errors") { error_messages(record) }
          end
        end

        def error_messages(record)
          record.errors_list.map(&:message).join(", ")
        end
      end
    end
  end
end
