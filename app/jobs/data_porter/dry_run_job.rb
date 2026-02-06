# frozen_string_literal: true

module DataPorter
  class DryRunJob < ActiveJob::Base
    queue_as { DataPorter.configuration.queue_name }

    def perform(import_id)
      data_import = DataImport.find(import_id)
      Orchestrator.new(data_import).dry_run!
    end
  end
end
