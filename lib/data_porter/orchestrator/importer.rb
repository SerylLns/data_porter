# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module Importer
      private

      def import_records
        prepare_writes(@data_import.importable_records)
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
        checkpoint = load_checkpoint
        results = seed_results(checkpoint)
        remaining = importable.drop(checkpoint[:processed])
        total = importable.size

        remaining.each_with_index do |record, index|
          persist_record(record, context, results)
          broadcast_progress(checkpoint[:processed] + index + 1, total, results: results)
        end

        finalize_import(results)
      end

      def import_all_or_nothing
        importable = @data_import.importable_records
        context = build_context
        results = empty_results

        ActiveRecord::Base.transaction do
          importable.each_with_index do |record, index|
            results[write_record(record, context)] += 1
            broadcast_progress(index + 1, importable.size)
          end
        end

        finalize_import(results)
      end

      def finalize_import(results)
        update_import_report(results)
        clear_checkpoint
        @data_import.update!(status: :completed)
        @broadcaster.success
        WebhookNotifier.notify(@data_import, "import.completed")
        results
      end

      def persist_record(record, context, results)
        results[write_record(record, context)] += 1
      rescue StandardError => e
        record.add_error(e.message)
        @target.on_error(record, e, context: context)
        results[:errored] += 1
      end

      def update_import_report(results)
        report = @data_import.report || StoreModels::Report.new
        report.imported_count = results[:created]
        report.updated_count = results[:updated]
        report.skipped_count = results[:skipped]
        report.errored_count = results[:errored]
        @data_import.update!(report: report)
      end

      def load_checkpoint
        cp = @data_import.config&.dig("checkpoint") || {}
        { processed: cp["processed"].to_i }.merge(RecordWriter::RESULT_KEYS.to_h { |key| [key, cp[key.to_s].to_i] })
      end

      def seed_results(checkpoint)
        checkpoint.slice(*RecordWriter::RESULT_KEYS)
      end

      def clear_checkpoint
        config = @data_import.config || {}
        config.delete("checkpoint")
        @data_import.update_column(:config, config)
      end
    end
  end
end
