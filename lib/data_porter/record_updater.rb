# frozen_string_literal: true

module DataPorter
  class RecordUpdater
    def initialize(data_import)
      @data_import = data_import
      @target = data_import.target_class.new
      @revalidator = RecordRevalidator.new(@target)
    end

    def call(line_number:, column:, value:)
      record = find_record(line_number)
      old_status = record.status
      update_cell(record, column, value)
      @revalidator.call(record)
      update_report(old_status, record.status)
      persist!
      build_response(record, column)
    end

    private

    def find_record(line_number)
      record = @data_import.records.find { |r| r.line_number == line_number }
      raise Error, "Record #{line_number} not found" unless record

      record
    end

    def update_cell(record, column, value)
      key = resolve_key(record.data, column)
      record.data[key] = value
    end

    def resolve_key(_data, column)
      column.to_s
    end

    def update_report(old_status, new_status)
      return if old_status == new_status

      report = @data_import.report
      decrement_count(report, old_status)
      increment_count(report, new_status)
    end

    def decrement_count(report, status)
      attr = count_attribute(status)
      report.send(:"#{attr}=", [report.send(attr) - 1, 0].max)
    end

    def increment_count(report, status)
      attr = count_attribute(status)
      report.send(:"#{attr}=", report.send(attr) + 1)
    end

    def count_attribute(status)
      {
        "complete" => :complete_count,
        "partial" => :partial_count,
        "missing" => :missing_count
      }.fetch(status, :partial_count)
    end

    def persist!
      @data_import.update!(
        records: @data_import.records,
        report: @data_import.report
      )
    end

    def build_response(record, column)
      key = resolve_key(record.data, column)
      {
        status: record.status,
        value: record.data[key].to_s,
        errors: record.errors_list.map(&:message),
        report: report_hash
      }
    end

    def report_hash
      r = @data_import.report
      {
        complete_count: r.complete_count,
        partial_count: r.partial_count,
        missing_count: r.missing_count,
        duplicate_count: r.duplicate_count
      }
    end
  end
end
