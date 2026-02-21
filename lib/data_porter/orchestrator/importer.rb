# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module Importer
      private

      def import_records
        if @target.class._bulk_config
          import_bulk
        elsif DataPorter.configuration.transaction_mode == :all
          import_all_or_nothing
        else
          import_per_record
        end
      end

      def import_per_record
        importable = @data_import.importable_records
        context = build_context
        results = { created: 0, errored: 0 }
        total = importable.size

        importable.each_with_index do |record, index|
          persist_record(record, context, results)
          broadcast_progress(index + 1, total)
        end

        finalize_import(results)
      end

      def import_all_or_nothing
        importable = @data_import.importable_records
        context = build_context
        total = importable.size

        ActiveRecord::Base.transaction do
          importable.each_with_index do |record, index|
            @target.persist(record, context: context)
            broadcast_progress(index + 1, total)
          end
        end

        finalize_import(created: total, errored: 0)
      end

      def finalize_import(results)
        @data_import.update!(status: :completed)
        @broadcaster.success
        WebhookNotifier.notify(@data_import, "import.completed")
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
