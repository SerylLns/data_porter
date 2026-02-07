# frozen_string_literal: true

module DataPorter
  module Concerns
    module ImportValidation
      extend ActiveSupport::Concern

      private

      def valid_source_for_target?
        target = DataPorter::Registry.find(@import.target_key)
        allowed = target._sources || DataPorter.configuration.enabled_sources
        return true if allowed.map(&:to_s).include?(@import.source_type.to_s)

        @import.errors.add(:source_type, "#{@import.source_type} is not available for this target")
        false
      end

      def valid_file_presence?
        return true unless %w[csv json xlsx].include?(@import.source_type)
        return true if @import.file.attached?

        @import.errors.add(:file, "must be attached for #{@import.source_type.upcase} imports")
        false
      end

      def valid_import_params?
        missing = missing_required_params
        return true if missing.empty?

        missing.each { |p| @import.errors.add(:base, "#{p.label} is required") }
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
    end
  end
end
