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

      def header_row_index
        config = @data_import.config
        from_config = config["header_row"] if config.is_a?(Hash)
        from_config&.to_i || @target_class._header_row || 0
      end

      def fallback_headers(raw_headers)
        stripped = raw_headers.reverse.drop_while(&:blank?).reverse
        return stripped if stripped.any?(&:present?)

        stripped.each_with_index.map { |_, i| "col_#{i + 1}" }
      end
    end
  end
end
