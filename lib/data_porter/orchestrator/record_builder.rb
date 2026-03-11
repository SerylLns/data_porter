# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module RecordBuilder
      private

      def build_records
        source = build_source
        raw_rows = source.fetch
        enforce_max_records!(raw_rows.size)
        columns = @target.class._columns || []
        validator = RecordValidator.new(columns)

        raw_rows.each_with_index.map do |row, index|
          build_record(row, index, columns, validator)
        end
      end

      def enforce_max_records!(count)
        max = DataPorter.configuration.max_records
        return unless max
        return if count <= max

        raise Error, I18n.t("data_porter.errors.max_records", count: count, max: max)
      end

      def build_record(row, index, columns, validator)
        record = StoreModels::ImportRecord.new(
          line_number: index + 1,
          data: extract_data(row, columns)
        )
        ColumnTransformer.apply_all(record, columns)
        record = @target.transform(record)
        @target.validate(record)
        validator.validate(record)
        record.determine_status!
        record
      end

      def extract_data(row, columns)
        columns.each_with_object({}) do |col, hash|
          hash[col.name.to_s] = row[col.name.to_s] || row[col.name]
        end
      end
    end
  end
end
