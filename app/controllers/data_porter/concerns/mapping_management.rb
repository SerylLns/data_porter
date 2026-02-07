# frozen_string_literal: true

module DataPorter
  module Concerns
    module MappingManagement
      extend ActiveSupport::Concern

      private

      def load_mapping_data
        target = @import.target_class
        columns = target._columns || []
        @file_headers = @import.config["file_headers"] || []
        @target_columns = columns.map { |c| [c.label, c.name.to_s, c.required] }
        @default_mapping = (target._csv_mappings || {}).transform_values(&:to_s)
        @templates = load_templates
      end

      def load_templates
        return [] unless defined?(DataPorter::MappingTemplate)

        DataPorter::MappingTemplate.for_target(@import.target_key)
      end

      def save_column_mapping
        mapping = params.require(:column_mapping).permit!.to_h
        merged = (@import.config || {}).merge("column_mapping" => mapping)
        @import.update!(config: merged, status: :pending)
      end

      def save_template_if_requested
        return unless params[:save_template] == "1"
        return unless defined?(DataPorter::MappingTemplate)

        mapping = params.require(:column_mapping).permit!.to_h
        DataPorter::MappingTemplate.find_or_initialize_by(
          target_key: @import.target_key,
          name: params[:template_name].presence || "Default"
        ).update!(mapping: mapping)
      end
    end
  end
end
