# frozen_string_literal: true

require "json"

module DataPorter
  module Components
    module Mapping
      class Form < Base
        def initialize(import:, action_url:, **options)
          super()
          @import = import
          @action_url = action_url
          @csrf_token = options[:csrf_token]
          @file_headers = options.fetch(:file_headers)
          @target_columns = options.fetch(:target_columns)
          @templates = options.fetch(:templates)
          @default_mapping = options.fetch(:default_mapping)
        end

        def view_template
          form(
            action: @action_url,
            method: "post",
            class: "dp-mapping-form",
            data_controller: "data-porter--mapping",
            data_data_porter__mapping_required_columns_value: required_columns_json
          ) { render_form_body }
        end

        private

        def render_form_body
          render_csrf_token
          render_method_override
          render_template_section
          render_warning("required")
          render_warning("duplicate")
          render_column_rows
          render_save_template
          render_actions
        end

        def render_csrf_token
          return unless @csrf_token

          input(type: "hidden", name: "authenticity_token", value: @csrf_token)
        end

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

        def render_warning(type)
          div(
            class: "dp-mapping-#{type}-warning",
            data_data_porter__mapping_target: "#{type}Warning",
            style: "display: none;"
          ) { "" }
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
            render_template_checkbox
            render_template_name_input
          end
        end

        def render_template_checkbox
          label(style: "display: flex; align-items: center; gap: 0.5rem;") do
            input(type: "checkbox", name: "save_template", value: "1")
            span { "Save as template" }
          end
        end

        def render_template_name_input
          input(
            type: "text", name: "template_name",
            placeholder: "Template name",
            class: "dp-select",
            style: "margin-top: 0.5rem;"
          )
        end

        def render_actions
          div(class: "dp-actions") do
            button(type: "submit", class: "dp-btn dp-btn--primary") { "Continue" }
          end
        end

        def required_columns_json
          @target_columns
            .select { |_, _, required| required }
            .map { |label, name, _| { label: label, name: name } }
            .to_json
        end
      end
    end
  end
end
