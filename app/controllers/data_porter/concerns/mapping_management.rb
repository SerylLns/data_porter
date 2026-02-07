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
        merged = (@import.config || {}).merge("column_mapping" => permitted_column_mapping)
        @import.update!(config: merged, status: :pending)
      end

      def save_template_if_requested
        return unless params[:save_template] == "1"
        return unless defined?(DataPorter::MappingTemplate)

        DataPorter::MappingTemplate.find_or_initialize_by(
          target_key: @import.target_key,
          name: params[:template_name].presence || "Default"
        ).update!(mapping: permitted_column_mapping)
      end

      def permitted_column_mapping
        raw = params.require(:column_mapping).permit!.to_h
        valid_names = valid_column_names
        raw.transform_values { |v| valid_names.include?(v) ? v : "" }
      end

      def valid_column_names
        columns = @import.target_class._columns || []
        columns.to_set { |c| c.name.to_s }
      end
    end
  end
end
