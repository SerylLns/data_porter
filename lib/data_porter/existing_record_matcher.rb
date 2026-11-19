# frozen_string_literal: true

module DataPorter
  class ExistingRecordMatcher
    BATCH_SIZE = 1_000

    def self.for(target)
      keys = target.class._match_keys
      columns = target.class._columns || []
      new(target.existing_scope, keys, caster: ValueCaster.new(columns))
    end

    def initialize(scope, keys, caster: ValueCaster.new([]))
      @scope = scope
      @keys = keys.map(&:to_s)
      @caster = caster
    end

    def call(records)
      tuples = records.map { |record| key_for(record) }.reject { |tuple| blank_key?(tuple) }.uniq
      tuples.each_slice(self.class::BATCH_SIZE).with_object({}) do |batch, index|
        fetch(batch).each { |model| (index[model_key(model)] ||= []) << model }
      end
    end

    def key_for(record)
      @keys.map { |key| @caster.call(key, record.data[key]) }
    end

    def blank_key?(tuple)
      tuple.any? { |value| value.nil? || value.to_s.strip.empty? }
    end

    private

    def fetch(batch)
      wanted = batch.to_set
      @scope.where(conditions_for(batch)).select { |model| wanted.include?(model_key(model)) }
    end

    def conditions_for(batch)
      @keys.each_with_index.to_h { |key, i| [key, batch.map { |tuple| tuple[i] }.uniq] }
    end

    def model_key(model)
      @keys.map { |key| @caster.call(key, model.public_send(key)) }
    end
  end
end
