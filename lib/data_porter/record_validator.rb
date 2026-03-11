# frozen_string_literal: true

module DataPorter
  class RecordValidator
    def initialize(columns)
      @columns = columns
    end

    def validate(record)
      @columns.each do |col|
        value = record.data[col.name.to_s]
        validate_required(record, col, value)
        validate_type(record, col, value)
      end
    end

    private

    def validate_required(record, col, value)
      return unless col.required && value.to_s.strip.empty?

      record.add_error(I18n.t("data_porter.errors.required", label: col.label))
    end

    def validate_type(record, col, value)
      return if value.to_s.strip.empty?
      return if TypeValidator.valid?(value, col.type, col.options)

      record.add_error(I18n.t("data_porter.errors.invalid_type", label: col.label, type: col.type))
    end
  end
end
