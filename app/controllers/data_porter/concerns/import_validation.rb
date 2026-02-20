# frozen_string_literal: true

module DataPorter
  module Concerns
    module ImportValidation
      extend ActiveSupport::Concern

      ALLOWED_CONTENT_TYPES = {
        "csv" => %w[text/csv text/plain],
        "json" => %w[application/json text/plain],
        "xlsx" => %w[application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]
      }.freeze

      private

      def valid_source_for_target?
        target = DataPorter::Registry.find(@import.target_key)
        allowed = target._sources || DataPorter.configuration.enabled_sources
        return true if allowed.map(&:to_s).include?(@import.source_type.to_s)

        @import.errors.add(:source_type, I18n.t("data_porter.errors.source_unavailable", source: @import.source_type))
        false
      end

      def valid_file_presence?
        return true unless %w[csv json xlsx].include?(@import.source_type)
        return true if @import.file.attached?

        @import.errors.add(:file, I18n.t("data_porter.errors.file_required", source: @import.source_type.upcase))
        false
      end

      def valid_import_params?
        missing = missing_required_params
        return true if missing.empty?

        missing.each { |p| @import.errors.add(:base, I18n.t("data_porter.errors.required", label: p.label)) }
        false
      end

      def missing_required_params
        target = DataPorter::Registry.find(@import.target_key)
        required = (target._params || []).select(&:required)
        values = import_param_values
        required.reject { |p| values[p.name.to_s].present? }
      end

      def import_param_values
        (@import.config || {}).fetch("import_params", {})
      end

      def valid_file_size?
        return true unless @import.file.attached?

        max = DataPorter.configuration.max_file_size
        return true if @import.file.blob.byte_size <= max

        @import.errors.add(:file, I18n.t("data_porter.errors.file_too_large", max: max / 1.megabyte))
        false
      end

      def valid_file_content_type?
        return true unless @import.file.attached?

        allowed = ALLOWED_CONTENT_TYPES[@import.source_type]
        return true unless allowed

        content_type = @import.file.blob.content_type
        return true if allowed.include?(content_type)

        @import.errors.add(:file, I18n.t("data_porter.errors.invalid_content_type", type: content_type))
        false
      end
    end
  end
end
