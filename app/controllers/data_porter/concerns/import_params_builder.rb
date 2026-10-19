# frozen_string_literal: true

module DataPorter
  module Concerns
    module ImportParamsBuilder
      extend ActiveSupport::Concern

      private

      def import_params
        permitted = params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
        permitted = merge_import_params(permitted)
        merge_header_row(permitted)
      end

      def merge_import_params(permitted)
        nested = params.dig(:data_import, :config, :import_params)
        return permitted unless nested

        config = permitted[:config]&.to_unsafe_h || {}
        config["import_params"] = nested.permit(*allowed_param_keys).to_h
        permitted.merge(config: config)
      end

      def merge_header_row(permitted)
        raw = params.dig(:data_import, :header_row)
        return permitted if raw.blank?

        config = permitted[:config]&.to_unsafe_h || {}
        config["header_row"] = [raw.to_i - 1, 0].max
        permitted.merge(config: config)
      end

      def allowed_param_keys
        target_key = params.dig(:data_import, :target_key)
        return [] unless target_key

        target = DataPorter::Registry.find(target_key)
        (target._params || []).map { |p| p.name.to_s }
      end
    end
  end
end
