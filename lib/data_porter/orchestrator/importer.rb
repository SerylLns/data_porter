# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module Importer
      private

      def import_records
        importable = @data_import.importable_records
        context = build_context
        results = { created: 0, errored: 0 }
        total = importable.size

        importable.each_with_index do |record, index|
          persist_record(record, context, results)
          broadcast_progress(index + 1, total)
        end

        @data_import.update!(status: :completed)
        @broadcaster.success
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
    end
  end
end
