# frozen_string_literal: true

module DataPorter
  module Components
    module Mapping
      class TemplateSelect < Base
        def initialize(templates:, selected_id: nil)
          super()
          @templates = templates
          @selected_id = selected_id
        end

        def view_template
          select(
            class: "dp-select dp-mapping-template",
            data_action: "change->data-porter--mapping#loadTemplate"
          ) do
            option(value: "") { I18n.t("data_porter.mapping.select_template") }
            @templates.each { |t| render_option(t) }
          end
        end

        private

        def render_option(template)
          option(
            value: template.id.to_s,
            selected: template.id == @selected_id,
            data_mapping: template.mapping.to_json
          ) { template.name }
        end
      end
    end
  end
end
