# frozen_string_literal: true

module DataPorter
  class RecordRevalidator
    def initialize(target)
      @target = target
      @columns = target.class._columns || []
      @validator = RecordValidator.new(@columns)
    end

    def call(record)
      normalize_keys(record)
      ColumnTransformer.apply_all(record, @columns)
      @target.transform(record)
      record.errors_list = []
      @target.validate(record)
      @validator.validate(record)
      record.determine_status!
      record
    end

    private

    def normalize_keys(record)
      @columns.each do |col|
        string_key = col.name.to_s
        next unless record.data.key?(string_key) && !record.data.key?(col.name)

        record.data[col.name] = record.data.delete(string_key)
      end
    end
  end
end
