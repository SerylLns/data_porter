# frozen_string_literal: true

module DataPorter
  class RecordUpdater
    STATUS_COUNTS = {
      "complete" => :complete_count,
      "partial" => :partial_count,
      "missing" => :missing_count
    }.freeze

    ACTION_COUNTS = {
      "create" => :create_count,
      "update" => :update_count,
      "unchanged" => :unchanged_count
    }.freeze

    def initialize(data_import)
      @data_import = data_import
      @target = data_import.target_class.new
      @target.import_params = data_import.config&.dig("import_params") || {}
      @revalidator = RecordRevalidator.new(@target)
      @resolver = RecordActionResolver.new(@target) if @target.class._match_keys
    end

    def call(line_number:, column:, value:)
      record = find_record(line_number)
      old_status = record.status
      old_action = record.action
      update_cell(record, column, value)
      @revalidator.call(record)
      @resolver&.call_one(record, @data_import.records)
      update_report(old_status, old_action, record)
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

    def update_report(old_status, old_action, record)
      shift_count(STATUS_COUNTS.fetch(old_status, :partial_count), STATUS_COUNTS.fetch(record.status, :partial_count))
      shift_count(ACTION_COUNTS[old_action], ACTION_COUNTS[record.action]) unless record.excluded
    end

    def shift_count(from, to)
      return if from == to

      report = @data_import.report
      report.send(:"#{from}=", [report.send(from) - 1, 0].max) if from
      report.send(:"#{to}=", report.send(to) + 1) if to
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
        action: record.action,
        diff: record.diff,
        value: record.data[key].to_s,
        errors: record.errors_list.map(&:message),
        report: @data_import.report.preview_counts
      }
    end
  end
end
