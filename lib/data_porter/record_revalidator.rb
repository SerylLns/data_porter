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
        next if record.data.key?(string_key)
        next unless record.data.key?(col.name)

        record.data[string_key] = record.data.delete(col.name)
      end
    end
  end
end
