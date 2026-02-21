# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module BulkImporter
      private

      def import_bulk
        importable = @data_import.importable_records
        context = build_context
        bulk_config = @target.class._bulk_config
        results = { created: 0, errored: 0 }

        process_batches(importable, context, bulk_config, results)
        finalize_import(results)
      end

      def process_batches(importable, context, bulk_config, results)
        total = importable.size
        processed = 0

        importable.each_slice(bulk_config[:batch_size]) do |batch|
          persist_batch_with_fallback(batch, context, bulk_config, results)
          processed += batch.size
          broadcast_progress(processed, total, results: results)
        end
      end

      def persist_batch_with_fallback(batch, context, config, results)
        @target.persist_batch(batch, context: context)
        results[:created] += batch.size
      rescue StandardError => e
        handle_batch_failure(batch, context, config, results, e)
      end

      def handle_batch_failure(batch, context, config, results, error)
        if config[:on_conflict] == :fail_batch
          fail_batch(batch, results, error)
        else
          retry_per_record(batch, context, results)
        end
      end

      def fail_batch(batch, results, error)
        batch.each do |record|
          record.add_error(error.message)
        end
        results[:errored] += batch.size
      end

      def retry_per_record(batch, context, results)
        batch.each do |record|
          persist_record(record, context, results)
        end
      end
    end
  end
end
