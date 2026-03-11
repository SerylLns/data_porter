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
        @default_mapping = saved_or_default_mapping(target)
        @templates = load_templates
      end

      def load_templates
        return [] unless defined?(DataPorter::MappingTemplate)

        scope = scoped_template_base
        scope.for_target(@import.target_key)
      end

      def saved_or_default_mapping(target)
        saved = @import.config&.dig("column_mapping")
        return saved if saved.present?

        code_mapping = (target._csv_mappings || {}).transform_values(&:to_s)
        return code_mapping if code_mapping.present?

        auto_map_suggestions(target)
      end

      def auto_map_suggestions(target)
        columns = target._columns || []
        return {} if columns.empty? || @file_headers.empty?

        custom = columns.each_with_object({}) do |col, hash|
          hash[col.name] = col.synonyms if col.synonyms.any?
        end

        AutoMapper.new(@file_headers, columns.map(&:name), custom_synonyms: custom).call
      end

      def save_column_mapping
        merged = (@import.config || {}).merge("column_mapping" => permitted_column_mapping)
        @import.update!(config: merged, status: :pending)
      end

      def save_template_if_requested
        return unless params[:save_template] == "1"
        return unless defined?(DataPorter::MappingTemplate)

        template = scoped_template_base.find_or_initialize_by(
          target_key: @import.target_key,
          name: params[:template_name].presence || "Default"
        )
        template.user ||= resolve_owner
        template.update!(mapping: permitted_column_mapping)
      end

      def scoped_template_base
        owner = resolve_owner
        return DataPorter::MappingTemplate unless owner

        DataPorter::MappingTemplate.where(user: owner)
      end

      def permitted_column_mapping
        raw = params[:column_mapping]
        raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        raw = raw.to_h unless raw.is_a?(Hash)
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
