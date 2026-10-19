# frozen_string_literal: true

module DataPorter
  class ExistingRecordMatcher
    BATCH_SIZE = 1_000

    def initialize(scope, keys)
      @scope = scope
      @keys = keys.map(&:to_s)
    end

    def call(records)
      tuples = records.map { |record| key_for(record) }.reject { |tuple| tuple.any?(&:blank?) }.uniq
      tuples.each_slice(self.class::BATCH_SIZE).with_object({}) do |batch, index|
        fetch(batch).each { |model| (index[model_key(model)] ||= []) << model }
      end
    end

    def key_for(record)
      @keys.map { |key| record.data[key].to_s }
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
      @keys.map { |key| model.public_send(key).to_s }
    end
  end
end
