# frozen_string_literal: true

require "json"

module DataPorter
  module Components
    module Mapping
      class Form < Base
        def initialize(import:, file_headers:, target_columns:, templates:, default_mapping:, action_url:)
          super()
          @import = import
          @file_headers = file_headers
          @target_columns = target_columns
          @templates = templates
          @default_mapping = default_mapping
          @action_url = action_url
        end

        def view_template
          form(
            action: @action_url,
            method: "post",
            class: "dp-mapping-form",
            data_controller: "data-porter--mapping"
          ) do
            render_method_override
            render_template_section
            render_column_rows
            render_save_template
            render_actions
          end
        end

        private

        def render_method_override
          input(type: "hidden", name: "_method", value: "patch")
        end

        def render_template_section
          return if @templates.empty?

          div(class: "dp-field") do
            label(class: "dp-label") { "Load Template" }
            render TemplateSelect.new(templates: @templates)
          end
        end

        def render_column_rows
          div(class: "dp-mapping-rows") do
            @file_headers.each { |header| render_row(header) }
          end
        end

        def render_row(header)
          selected = @default_mapping[header]
          render ColumnRow.new(
            file_header: header,
            target_fields: @target_columns,
            selected: selected
          )
        end

        def render_save_template
          div(class: "dp-field", style: "margin-top: 1.5rem;") do
            label(style: "display: flex; align-items: center; gap: 0.5rem;") do
              input(type: "checkbox", name: "save_template", value: "1")
              span { "Save as template" }
            end
            input(
              type: "text", name: "template_name",
              placeholder: "Template name",
              class: "dp-select",
              style: "margin-top: 0.5rem;"
            )
          end
        end

        def render_actions
          div(class: "dp-actions") do
            button(type: "submit", class: "dp-btn dp-btn--primary") { "Continue" }
          end
        end
      end
    end
  end
end
