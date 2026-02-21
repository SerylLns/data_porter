# frozen_string_literal: true

require_relative "orchestrator/record_builder"
require_relative "orchestrator/importer"
require_relative "orchestrator/bulk_importer"
require_relative "orchestrator/dry_runner"

module DataPorter
  class Orchestrator
    include RecordBuilder
    include Importer
    include BulkImporter
    include DryRunner

    def initialize(data_import, content: nil)
      @data_import = data_import
      @target = build_target(data_import)
      @broadcaster = Broadcaster.new(data_import.id)
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
      WebhookNotifier.notify(@data_import, "import.parsed")
    rescue StandardError => e
      handle_failure(e)
    end

    def import!
      @data_import.importing!
      WebhookNotifier.notify(@data_import, "import.started")
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

    def build_target(data_import)
      target = data_import.target_class.new
      config = data_import.config || {}
      target.import_params = config["import_params"] || {}
      target
    end

    def build_source
      @data_import.source_class.new(@data_import, **@source_options)
    end

    def store_headers(headers)
      config = @data_import.config || {}
      config["file_headers"] = headers
      @data_import.update!(config: config)
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

    def broadcast_progress(current, total, results: nil)
      config = @data_import.config || {}
      config["progress"] = { "current" => current, "total" => total, "percentage" => pct(current, total) }
      save_checkpoint(config, current, results) if results
      @data_import.update_column(:config, config)
      @broadcaster.progress(current, total)
    end

    def pct(current, total)
      ((current.to_f / total) * 100).round
    end

    def save_checkpoint(config, processed, results)
      config["checkpoint"] = {
        "processed" => processed,
        "created" => results[:created],
        "errored" => results[:errored]
      }
    end

    def handle_failure(error)
      report = @data_import.report || StoreModels::Report.new
      report.error_reports = [StoreModels::Error.new(message: error.message)]
      @data_import.update!(status: :failed, report: report)
      @broadcaster.failure(error.message)
      WebhookNotifier.notify(@data_import, "import.failed")
    end
  end
end
