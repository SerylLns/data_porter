# frozen_string_literal: true

module DataPorter
  class RecordDiffer
    def initialize(target)
      @target = target
      @caster = ValueCaster.new(target.class._columns || [])
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
      @caster.call(field, old_value) == @caster.call(field, new_value)
    end
  end
end
