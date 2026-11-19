# frozen_string_literal: true

module DataPorter
  module Components
    module Preview
      class Table < Base
        ACTIONS = %w[create update unchanged].freeze

        def initialize(columns:, records:, editable: false, update_mode: false, urls: {})
          super()
          @columns = columns
          @records = records
          @editable = editable
          @update_mode = update_mode
          @urls = urls
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
            "data-porter--inline-edit-update-url-value": @urls[:update]
          }
          attrs[:data].merge!(update_mode_data) if @update_mode
          attrs
        end

        def update_mode_data
          {
            "data-porter--inline-edit-action-labels-value" => action_labels.to_json,
            "data-porter--inline-edit-exclude-url-value" => @urls[:exclude]
          }.compact
        end

        def action_labels
          ACTIONS.to_h { |action| [action, action_label(action)] }
        end

        def action_label(action)
          I18n.t("data_porter.components.table.actions.#{action}")
        end

        def render_header
          thead do
            tr do
              th { I18n.t("data_porter.components.table.line_number") }
              th { I18n.t("data_porter.components.table.status") }
              th { I18n.t("data_porter.components.table.action") } if @update_mode
              th { I18n.t("data_porter.components.table.include") } if exclusion?
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
            render_action_cell(record) if @update_mode
            render_include_cell(record) if exclusion?
            @columns.each { |col| render_cell(record, col) }
            render_errors_cell(record)
          end
        end

        def render_action_cell(record)
          td(class: "dp-cell--action") do
            span(class: "dp-action dp-action--#{record.action}") { action_label(record.action) } if record.action
          end
        end

        def exclusion?
          @update_mode && @editable
        end

        def render_include_cell(record)
          td(class: "dp-cell--include") do
            input(type: "checkbox", class: "dp-exclude-toggle", checked: !record.excluded,
                  aria_label: I18n.t("data_porter.components.table.include"),
                  data: { action: "change->data-porter--inline-edit#toggleExclude", line_number: record.line_number })
          end
        end

        def render_cell(record, col)
          value = cell_value(record, col)
          change = cell_change(record, col)
          attrs = cell_attrs(record, col, value, change)
          attrs[:title] = value if value.length > 30
          td(**attrs) { change ? render_diff(change.first, value) : plain(value) }
        end

        def render_diff(old_value, new_value)
          span(class: "dp-diff__old") { old_value.to_s }
          span(class: "dp-diff__new") { new_value }
        end

        def cell_change(record, col)
          return unless @update_mode

          record.diff[col.name.to_s]
        end

        def render_errors_cell(record)
          td(**errors_cell_attrs(record)) { error_messages(record) }
        end

        def cell_value(record, col)
          record.data[col.name.to_s].to_s
        end

        def row_attrs(record)
          attrs = { class: ["dp-row--#{record.status}", ("dp-excluded" if record.excluded)].compact.join(" ") }
          return attrs unless @editable

          attrs[:data] = { line_number: record.line_number }
          attrs
        end

        def cell_attrs(record, col, value, change)
          attrs = change ? { class: "dp-cell--changed" } : {}
          return attrs unless @editable

          attrs.merge(class: ["dp-cell--editable", attrs[:class]].compact.join(" "),
                      data: editable_cell_data(record, col, value, change))
        end

        def editable_cell_data(record, col, value, change)
          {
            action: "click->data-porter--inline-edit#edit",
            "data-porter--inline-edit-target": "cell",
            value: value,
            old_value: change&.first&.to_s,
            line_number: record.line_number,
            column: col.name.to_s
          }.compact
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
