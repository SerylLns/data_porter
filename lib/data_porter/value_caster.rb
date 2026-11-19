# frozen_string_literal: true

module DataPorter
  class ValueCaster
    CASTERS = {
      integer: ActiveModel::Type::Integer.new,
      decimal: ActiveModel::Type::Decimal.new,
      boolean: ActiveModel::Type::Boolean.new,
      date: ActiveModel::Type::Date.new
    }.freeze

    def self.blank?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    def initialize(columns)
      @types = columns.to_h { |column| [column.name.to_s, column.type] }
    end

    def call(field, value)
      return nil if self.class.blank?(value)

      caster = CASTERS[@types[field.to_s]]
      caster ? caster.cast(value) : value.to_s
    end
  end
end
