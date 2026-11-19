# frozen_string_literal: true

module DataPorter
  class RecordExcluder
    ACTION_COUNTS = RecordUpdater::ACTION_COUNTS

    def initialize(data_import)
      @data_import = data_import
      @report = data_import.report
    end

    def call(line_number:, excluded:)
      record = find_record(line_number)
      unless record.excluded == excluded
        record.excluded = excluded
        shift_counts(record)
        persist!
      end
      { excluded: record.excluded, report: @report.preview_counts }
    end

    private

    def find_record(line_number)
      record = @data_import.records.find { |r| r.line_number == line_number }
      raise Error, "Record #{line_number} not found" unless record

      record
    end

    def shift_counts(record)
      action_key = ACTION_COUNTS[record.action]
      step = record.excluded ? 1 : -1
      @report.excluded_count = [@report.excluded_count + step, 0].max
      @report.public_send(:"#{action_key}=", [@report.public_send(action_key) - step, 0].max) if action_key
    end

    def persist!
      @data_import.records_will_change!
      @data_import.update!(records: @data_import.records, report: @report)
    end
  end
end
