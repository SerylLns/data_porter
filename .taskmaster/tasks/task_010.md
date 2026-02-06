# Task ID: 10

**Title:** Create ActiveJob classes (ParseJob, ImportJob)

**Status:** pending

**Dependencies:** 9

**Priority:** high

**Description:** Implement DataPorter::ParseJob and DataPorter::ImportJob that delegate to the Orchestrator. Both use configurable queue_name.

**Details:**

Create app/jobs/data_porter/parse_job.rb: inherits ActiveJob::Base, queue_as from DataPorter.configuration.queue_name, perform(import_id) finds DataImport and calls Orchestrator.new(data_import).parse!. Create app/jobs/data_porter/import_job.rb: same pattern but calls orchestrator.import!.

**Test Strategy:**

Test jobs enqueue correctly. Test they find the DataImport and call the right orchestrator method. Test queue configuration.
