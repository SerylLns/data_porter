# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module DryRunner
      private

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
        ActiveRecord::Base.transaction do
          @target.persist(record, context: context)
          record.dry_run_passed = true
          raise ActiveRecord::Rollback
        end
      rescue ActiveRecord::Rollback
        nil
      rescue StandardError => e
        record.dry_run_passed = false
        record.add_error(e.message)
      end
    end
  end
end
