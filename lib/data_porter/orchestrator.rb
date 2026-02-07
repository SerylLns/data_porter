# frozen_string_literal: true

module DataPorter
  class Orchestrator
    def initialize(data_import, content: nil)
      @data_import = data_import
      @target = data_import.target_class.new
      @source_options = { content: content }.compact
    end

    def extract_headers!
      @data_import.extracting_headers!
      source = build_source
      headers = source.headers
      store_headers(headers)
      @data_import.update!(status: :mapping)
    rescue StandardError => e
      handle_failure(e)
    end

    def parse!
      @data_import.parsing!
      records = build_records
      @data_import.update!(records: records, status: :previewing)
      build_report
    rescue StandardError => e
      handle_failure(e)
    end

    def import!
      @data_import.importing!
      results = import_records
      update_import_report(results)
      @target.after_import(results, context: build_context)
    rescue StandardError => e
      handle_failure(e)
    end

    def dry_run!
      @data_import.dry_running!
      run_dry_run_records
      @data_import.update!(status: :previewing)
      build_report
    rescue StandardError => e
      handle_failure(e)
    end

    private

    def build_source
      @data_import.source_class.new(@data_import, **@source_options)
    end

    def store_headers(headers)
      config = @data_import.config || {}
      config["file_headers"] = headers
      @data_import.update!(config: config)
    end

    def build_records
      source = build_source
      raw_rows = source.fetch
      columns = @target.class._columns || []
      validator = RecordValidator.new(columns)

      raw_rows.each_with_index.map do |row, index|
        build_record(row, index, columns, validator)
      end
    end

    def build_record(row, index, columns, validator)
      record = StoreModels::ImportRecord.new(
        line_number: index + 1,
        data: extract_data(row, columns)
      )
      record = @target.transform(record)
      @target.validate(record)
      validator.validate(record)
      record.determine_status!
      record
    end

    def extract_data(row, columns)
      columns.each_with_object({}) do |col, hash|
        hash[col.name] = row[col.name] || row[col.name.to_s]
      end
    end

    def run_dry_run_records
      records = @data_import.records
      importable = records.select(&:importable?)
      context = build_context

      importable.each do |record|
        dry_run_record(record, context)
      end

      @data_import.records_will_change!
      @data_import.update!(records: records)
    end

    def dry_run_record(record, context)
      @target.persist(record, context: context)
      record.dry_run_passed = true
    rescue StandardError => e
      record.dry_run_passed = false
      record.add_error(e.message)
    end

    def import_records
      importable = @data_import.importable_records
      context = build_context
      results = { created: 0, errored: 0 }

      importable.each do |record|
        persist_record(record, context, results)
      end

      @data_import.update!(status: :completed)
      results
    end

    def persist_record(record, context, results)
      @target.persist(record, context: context)
      results[:created] += 1
    rescue StandardError => e
      record.add_error(e.message)
      @target.on_error(record, e, context: context)
      results[:errored] += 1
    end

    def update_import_report(results)
      report = @data_import.report || StoreModels::Report.new
      report.imported_count = results[:created]
      report.errored_count = results[:errored]
      @data_import.update!(report: report)
    end

    def build_report
      summary = @data_import.records_summary
      report = StoreModels::Report.new(
        records_count: @data_import.records.size,
        complete_count: summary["complete"] || 0,
        partial_count: summary["partial"] || 0,
        missing_count: summary["missing"] || 0
      )
      @data_import.update!(report: report)
    end

    def build_context
      DataPorter.configuration.context_builder&.call(@data_import)
    end

    def handle_failure(error)
      report = StoreModels::Report.new(
        error_reports: [StoreModels::Error.new(message: error.message)]
      )
      @data_import.update!(status: :failed, report: report)
    end
  end
end
