# frozen_string_literal: true

module DataPorter
  module Sources
    class Base
      def initialize(data_import, **)
        @data_import = data_import
        @target_class = data_import.target_class
      end

      def fetch
        raise NotImplementedError
      end

      private

      def apply_csv_mapping(row)
        return user_map(row) if user_mapping.any?

        code_mappings = @target_class._csv_mappings
        return explicit_map(row, code_mappings) if code_mappings&.any?

        auto_map(row)
      end

      def user_mapping
        config = @data_import.config
        return {} unless config.is_a?(Hash)

        config.fetch("column_mapping", {})
      end

      def user_map(row)
        user_mapping.each_with_object({}) do |(header, column), hash|
          hash[column.to_sym] = row[header]
        end
      end

      def explicit_map(row, mappings)
        mappings.each_with_object({}) do |(header, column), hash|
          hash[column] = row[header]
        end
      end

      def auto_map(row)
        row.to_h.transform_keys { |k| k.parameterize(separator: "_").to_sym }
      end
    end
  end
end
