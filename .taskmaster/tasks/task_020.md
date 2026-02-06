# Task ID: 20

**Title:** Implement Dry Run mode

**Status:** pending

**Dependencies:** 9, 10

**Priority:** low

**Description:** Add dry_run! method to Orchestrator that wraps persist calls in a transaction and rolls back. Enriches ImportRecords with DB-level validation errors. Add DryRunJob and controller action.

**Details:**

Add dry_run! to Orchestrator: transitions to dry_running, wraps all persist calls in ActiveRecord::Base.transaction, catches RecordInvalid/RecordNotUnique/StandardError per record, adds DB errors to import records, raises ActiveRecord::Rollback at end, resets target_ids, transitions back to previewing, rebuilds report. Create app/jobs/data_porter/dry_run_job.rb. Add dry_run action to controller. Add dry_run_enabled DSL flag to Target. Add dry_run_passed attribute to ImportRecord StoreModel.

**Test Strategy:**

Test that dry_run! rolls back all DB changes. Test that DB validation errors are captured on records. Test status transitions (previewing -> dry_running -> previewing). Test dry_run_enabled flag controls UI button visibility.
