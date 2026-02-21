# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module BulkImporter
      private

      def import_bulk
        importable = @data_import.importable_records
        checkpoint = load_checkpoint
        @bulk_state = build_bulk_state(importable, checkpoint)

        process_batches(importable.drop(checkpoint[:processed]))
        finalize_import(@bulk_state[:results])
      end

      def build_bulk_state(importable, checkpoint)
        {
          context: build_context,
          bulk_config: @target.class._bulk_config,
          results: seed_results(checkpoint),
          total: importable.size,
          processed: checkpoint[:processed]
        }
      end

      def process_batches(records)
        records.each_slice(@bulk_state[:bulk_config][:batch_size]) do |batch|
          persist_batch_with_fallback(batch)
          @bulk_state[:processed] += batch.size
          broadcast_progress(@bulk_state[:processed], @bulk_state[:total], results: @bulk_state[:results])
        end
      end

      def persist_batch_with_fallback(batch)
        @target.persist_batch(batch, context: @bulk_state[:context])
        @bulk_state[:results][:created] += batch.size
      rescue StandardError => e
        handle_batch_failure(batch, e)
      end

      def handle_batch_failure(batch, error)
        if @bulk_state[:bulk_config][:on_conflict] == :fail_batch
          fail_batch(batch, error)
        else
          retry_per_record(batch)
        end
      end

      def fail_batch(batch, error)
        batch.each { |record| record.add_error(error.message) }
        @bulk_state[:results][:errored] += batch.size
      end

      def retry_per_record(batch)
        batch.each do |record|
          persist_record(record, @bulk_state[:context], @bulk_state[:results])
        end
      end
    end
  end
end
