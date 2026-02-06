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
        mappings = @target_class._csv_mappings
        return auto_map(row) if mappings.nil? || mappings.empty?

        explicit_map(row, mappings)
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
