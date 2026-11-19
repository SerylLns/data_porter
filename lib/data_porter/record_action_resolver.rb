# frozen_string_literal: true

module DataPorter
  class RecordActionResolver
    def initialize(target)
      @keys = target.class._match_keys
      @matcher = ExistingRecordMatcher.for(target)
      @differ = RecordDiffer.new(target)
    end

    def call(records)
      index = @matcher.call(records)
      @first_lines = {}
      records.each { |record| resolve(record, index) }
    end

    def call_one(record, records)
      index = @matcher.call([record])
      @first_lines = earlier_lines(record, records)
      resolve(record, index)
    end

    private

    def earlier_lines(record, records)
      records.select { |other| other.line_number < record.line_number }
             .each_with_object({}) { |other, lines| lines[@matcher.key_for(other)] ||= other.line_number }
    end

    def resolve(record, index)
      record.diff = {}
      key = @matcher.key_for(record)
      if @matcher.blank_key?(key)
        record.action = "create"
      else
        flag_duplicate(record, key)
        assign_action(record, index.fetch(key, []))
      end
      record.determine_status!
    end

    def flag_duplicate(record, key)
      first_line = @first_lines[key]
      return @first_lines[key] = record.line_number unless first_line

      record.add_error(I18n.t("data_porter.errors.duplicate_match_key", keys: keys_label, line: first_line))
    end

    def assign_action(record, matches)
      return record.action = "create" if matches.empty?
      return apply_diff(record, matches.first) if matches.one?

      record.add_error(I18n.t("data_porter.errors.ambiguous_match", keys: keys_label, count: matches.size))
    end

    def apply_diff(record, existing)
      record.diff = @differ.call(record, existing)
      record.action = record.diff.empty? ? "unchanged" : "update"
    end

    def keys_label
      @keys.join(", ")
    end
  end
end
