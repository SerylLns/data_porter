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
        @written_lines = {}
      end

      def write_record(record, context)
        return create_record(record, context) unless @existing_index

        key = @matcher.key_for(record)
        claim_key!(key, record)
        existing = existing_for(key)
        existing ? update_record(record, existing, context) : create_record(record, context)
      end

      def claim_key!(key, record)
        return if key.any?(&:blank?)

        first_line = @written_lines[key]
        return @written_lines[key] = record.line_number unless first_line

        raise Error, I18n.t("data_porter.errors.duplicate_match_key", keys: match_keys_label, line: first_line)
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

      def existing_for(key)
        matches = @existing_index.fetch(key, [])
        return matches.first unless matches.size > 1

        raise Error, I18n.t("data_porter.errors.ambiguous_match", keys: match_keys_label, count: matches.size)
      end

      def match_keys_label
        @target.class._match_keys.join(", ")
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
