# frozen_string_literal: true

module DataPorter
  class RecordDiffer
    CASTERS = {
      integer: ActiveModel::Type::Integer.new,
      decimal: ActiveModel::Type::Decimal.new,
      boolean: ActiveModel::Type::Boolean.new,
      date: ActiveModel::Type::Date.new
    }.freeze

    def initialize(target)
      @target = target
      @types = (target.class._columns || []).to_h { |column| [column.name.to_s, column.type] }
    end

    def call(record, existing)
      @target.diff_attributes(existing).each_with_object({}) do |(field, old_value), diff|
        new_value = record.data[field]
        next if new_value.nil? || same?(field, old_value, new_value)

        diff[field] = [old_value.as_json, new_value.as_json]
      end
    end

    private

    def same?(field, old_value, new_value)
      normalize(field, old_value) == normalize(field, new_value)
    end

    def normalize(field, value)
      return nil if value.nil? || value == ""

      caster = CASTERS[@types[field]]
      caster ? caster.cast(value) : value.to_s
    end
  end
end
