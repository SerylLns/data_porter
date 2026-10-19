# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module RecordWriter
      RESULT_KEYS = %i[created updated skipped errored].freeze

      private

      def prepare_writes(records)
        return unless @target.class._match_keys
        raise Error, "bulk_mode is not supported with match_by yet" if @target.class._bulk_config

        @matcher = ExistingRecordMatcher.new(@target.existing_scope, @target.class._match_keys)
        @existing_index = @matcher.call(records)
        @differ = RecordDiffer.new(@target)
      end

      def write_record(record, context)
        return create_record(record, context) unless @existing_index

        existing = existing_for(record)
        existing ? update_record(record, existing, context) : create_record(record, context)
      end

      def create_record(record, context)
        return :skipped unless apply?("apply_creates")

        @target.persist(record, context: context)
        :created
      end

      def update_record(record, existing, context)
        return :skipped unless apply?("apply_updates")
        return :skipped if @differ.call(record, existing).empty?

        @target.update(record, existing, context: context)
        :updated
      end

      def existing_for(record)
        matches = @existing_index.fetch(@matcher.key_for(record), [])
        return matches.first unless matches.size > 1

        keys = @target.class._match_keys.join(", ")
        raise Error, I18n.t("data_porter.errors.ambiguous_match", keys: keys, count: matches.size)
      end

      def apply?(flag)
        ActiveModel::Type::Boolean.new.cast(@data_import.config&.dig(flag)) != false
      end

      def empty_results
        RESULT_KEYS.index_with(0)
      end
    end
  end
end
