# Task ID: 9

**Title:** Build Orchestrator (parse and import flows)

**Status:** pending

**Dependencies:** 7, 8

**Priority:** high

**Description:** Implement DataPorter::Orchestrator that coordinates source + target for parse! and import! operations. Handles the full workflow: fetch data, transform, validate, build records, persist.

**Details:**

Create lib/data_porter/orchestrator.rb. initialize(data_import) sets up @source and @target instances. parse!: transitions to parsing, fetches raw rows from source, maps to ImportRecord StoreModels (applying transform and validate hooks, running run_validations!), broadcasts progress, saves records and transitions to previewing, builds report. import!: transitions to importing, iterates importable_records, calls target.persist for each with context, handles per-record errors via on_error hook, updates counts, transitions to completed, calls after_import. Private methods: broadcast_progress, broadcast_success, handle_failure (transitions to failed with error report), build_context (calls context_builder), build_report.

**Test Strategy:**

Test parse! creates ImportRecords from source data. Test import! calls persist for each importable record. Test error handling during parse and import. Test status transitions. Test progress broadcasting.
