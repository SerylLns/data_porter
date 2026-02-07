# frozen_string_literal: true

module DataPorter
  class ExtractHeadersJob < ActiveJob::Base
    queue_as { DataPorter.configuration.queue_name }

    def perform(import_id)
      data_import = DataImport.find(import_id)
      Orchestrator.new(data_import).extract_headers!
    end
  end
end
